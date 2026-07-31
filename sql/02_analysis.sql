/*==============================================================
  0. MISE EN PLACE
==============================================================*/

USE STORE_DB;

CREATE OR REPLACE VIEW sales_details_location AS (
	SELECT 
		l.region,
        l.state, 
        l.city,
        l.postal_code, 
        f.order_id,
        f.total_sales,
        f.quantity,
        f.profit
	FROM 
		df_facts AS f
	INNER JOIN 
		df_dim_location AS l
        ON f.location_id = l.location_id
);

CREATE OR REPLACE VIEW sales_details_product AS (
	SELECT
		p.product_id, 
        p.product_name,
        p.category, 
        p.sub_category, 
        p.price,
        f.order_id,
        f.customer_id,
        f.total_sales, 
        f.quantity, 
        f.profit,
        f.discount,
        f.upm_pre_discount,
        f.upm_post_discount
	FROM 
		df_facts AS f
	INNER JOIN 
		df_dim_product AS p
        ON f.product_id = p.product_id
);

/* Segmentation clientèle selon le nombre de commandes */

WITH decompte_commande AS (
    SELECT
        COUNT(DISTINCT order_id) AS nb_commandes_par_client
    FROM 
		df_facts
    GROUP BY 
		customer_id
)

SELECT
	nb_commandes_par_client,
    COUNT(*)
FROM 
	decompte_commande
GROUP BY 
	nb_commandes_par_client
ORDER BY 
	nb_commandes_par_client ASC;
    
/*
Aucune rupture nette n'apparaît dans la distribution du nombre de commandes. Les seuils retenus correspondent donc à une segmentation métier destinée 
à distinguer les clients ponctuels, les clients réguliers et les clients les plus engagés. L'objectif est de faciliter l'interprétation des analyses.
*/

CREATE OR REPLACE VIEW fidelite_clientele AS (
	SELECT 	
		CASE 
			WHEN COUNT(DISTINCT order_id) BETWEEN 1 AND 4 THEN "Ponctuel"
			WHEN COUNT(DISTINCT order_id) BETWEEN 5 AND 8 THEN "Régulier"
			ELSE "Fidèle"
			END AS categorie_client,
    customer_id
	FROM 
		df_facts
	GROUP BY 
		customer_id
);


/*==============================================================
  1. VUE D'ENSEMBLE DE L'ACTIVITÉ
  Objectif : 
  Informer sur le nombre de commandes, le CA, le volume de
  ventes et les profits sur l'ensemble des données.
==============================================================*/

SELECT 
	COUNT(DISTINCT order_id) AS nb_commandes,
	SUM(total_sales) AS chiffre_affaires,
    SUM(quantity) AS volume_ventes,
    SUM(profit) AS profit_total,
    SUM(profit)
    /
    SUM(total_sales) AS taux_marge,
    SUM(profit) 
    /
    COUNT(DISTINCT order_id) AS profit_par_panier, 
    SUM(quantity)
    /
    COUNT(DISTINCT order_id) AS articles_par_panier, 
    AVG(discount) AS taux_remise_moyenne,
    SUM(total_sales) 
    /
    COUNT(DISTINCT customer_id) AS ca_par_client, 
	SUM(profit) 
    /
    COUNT(DISTINCT customer_id) AS profit_par_client
FROM 
	df_facts;

/*==============================================================
  2. ANALYSE TEMPORELLE
  Objectif : 
  Identifier les années les plus porteuses et les récurrences
  mensuelles.
==============================================================*/

/* 2.1 Répartition des commandes, CA, ventes et profit par année */

SELECT 
	YEAR(order_date) AS order_year,
    COUNT(DISTINCT order_id) AS nb_commandes,
	SUM(total_sales) AS chiffre_affaires,
    SUM(quantity) AS volume_ventes,
    SUM(profit) AS profit_total
FROM 
	df_facts
GROUP BY 
	order_year
ORDER BY
	order_year ASC;

/* ----- Interprétation -----
L'activité lors des deux premières années est relativement similaire, à l'exception d'une hausse du profit significative. 
Un décollage a lieu au cours de l'année 2016 et se poursuit en 2017.
 -------------------------- */

/* 2.2 Contribution de chaque mois aux différents indicateurs */

WITH sales_month AS (
	SELECT 
		MONTH(order_date) AS order_month,
		COUNT(DISTINCT order_id) AS nb_commandes,
		SUM(total_sales) AS chiffre_affaires,
		SUM(quantity) AS volume_ventes,
		SUM(profit) AS profit_total
	FROM 
		df_facts
	GROUP BY 
		order_month
)

SELECT 
	order_month, 
	ROUND(
        nb_commandes / SUM(nb_commandes) OVER () *100,
        2
    ) AS pct_nb_commandes,
    ROUND(
        chiffre_affaires / SUM(chiffre_affaires) OVER () *100,
        2
    ) AS part_ca,
	ROUND(
	volume_ventes / SUM(volume_ventes) OVER () *100,
	2
	) AS pct_volume_ventes,
    ROUND(
        profit_total / SUM(profit_total) OVER () *100,
        2
    ) AS pct_profit_total
FROM 
	sales_month
ORDER BY
	order_month ASC;
    
/* ----- Interprétation -----
Les 4 derniers mois de l'année sont les plus profitables, plus de 50% du profit total.
L'activité se porte le moins bien lors des mois de janvier et février. 
 -------------------------- */

/*==============================================================
  3. ANALYSE GÉOGRAPHIQUE
  Objectif :
  Identifier les régions, États et villes qui contribuent le plus
  au chiffre d'affaires et au profit de l'entreprise.
==============================================================*/

/* 3.1 Bilan par Régions */

WITH sales_region AS (
    SELECT
        region,
        COUNT(DISTINCT order_id) AS nb_commandes,
        SUM(total_sales) AS chiffre_affaires,
        SUM(quantity) AS volume_ventes,
        SUM(profit) AS profit_total
    FROM 
		sales_details_location
    GROUP BY 
		region
)

SELECT
    region,
    nb_commandes,
        ROUND(
        nb_commandes / SUM(nb_commandes) OVER () *100,
        2
    ) AS pct_nb_commandes,
    chiffre_affaires,
    ROUND(
        chiffre_affaires / SUM(chiffre_affaires) OVER () *100,
        2
    ) AS part_ca,
    volume_ventes,
	ROUND(
		volume_ventes / SUM(volume_ventes) OVER () *100,
		2
	) AS pct_volume_ventes,
    profit_total,
    ROUND(
        profit_total / SUM(profit_total) OVER () *100,
        2
    ) AS pct_profit_total
FROM 
	sales_region
ORDER BY 
	pct_profit_total DESC;

/* ----- Interprétation -----
La région Ouest surperforme en terme de profit, affichant un poids dans le profit total de 6 points supérieur à son poids dans le CA.
C'est également le cas de la région Est mais dans une moindre mesure (2 point de différence).
Le Centre des Etats-Unis sous-performe largement avec une part du profit total inférieur de 8 points à sa part du CA. 
 -------------------------- */
    
/* 3.2 Top 10 États avec les plus hauts profits */

WITH sales_state AS (
    SELECT
        state,
        COUNT(DISTINCT order_id) AS nb_commandes,
        SUM(total_sales) AS chiffre_affaires,
        SUM(quantity) AS volume_ventes,
        SUM(profit) AS profit_total
    FROM 
		sales_details_location
    GROUP BY 
		state
)

SELECT
    state,
    nb_commandes,
        ROUND(
        nb_commandes / SUM(nb_commandes) OVER () *100,
        2
    ) AS pct_nb_commandes,
    chiffre_affaires,
    ROUND(
        chiffre_affaires / SUM(chiffre_affaires) OVER () *100,
        2
    ) AS part_ca,
    volume_ventes,
	ROUND(
	volume_ventes / SUM(volume_ventes) OVER () *100,
	2
	) AS pct_volume_ventes,
    profit_total,
    ROUND(
        profit_total / SUM(profit_total) OVER () *100,
        2
    ) AS pct_profit_total
FROM 
	sales_state
ORDER BY 
	pct_profit_total DESC
LIMIT 
	10;

/* ----- Interprétation -----
Les états de Californie et de New York représentent à eux deux plus de 50% des profits totaux, mais moins d'un tiers des ventes et du CA. 
Ces 10 états ont un poids systématiquement plus important dans le profit total que dans les autres indicateurs. 
 -------------------------- */

/* 3.3 Top 10 Villes avec les plus hauts profits*/

WITH sales_city AS (
    SELECT
		city,
        state,
        COUNT(DISTINCT order_id) AS nb_commandes,
        SUM(total_sales) AS chiffre_affaires,
        SUM(quantity) AS volume_ventes,
        SUM(profit) AS profit_total
    FROM 
		sales_details_location
    GROUP BY 
		city,
		state
)

SELECT
	city,
    state,
    nb_commandes,
        ROUND(
        nb_commandes / SUM(nb_commandes) OVER () *100,
        2
    ) AS pct_nb_commandes,
    chiffre_affaires,
    ROUND(
        chiffre_affaires / SUM(chiffre_affaires) OVER () *100,
        2
    ) AS part_ca,
    volume_ventes,
	ROUND(
	volume_ventes / SUM(volume_ventes) OVER () *100,
	2
	) AS pct_volume_ventes,
    profit_total,
    ROUND(
        profit_total / SUM(profit_total) OVER () *100,
        2
    ) AS pct_profit_total
FROM 
	sales_city
ORDER BY 
	pct_profit_total DESC
LIMIT 
	10;

/* ----- Interprétation -----
Les deux premières villes correspondent également aux plus grandes métropoles américaines, ce qui peut contribuer à expliquer leur poids économique.
Les 4 premières villes ont des poids importants dans les ventes quand les 6 suivantes ont des nombres de commandes ou des volumes de ventes très faibles.
 -------------------------- */

/*==============================================================
  4. ANALYSE CLIENT
  Objectif : 
  Identifier les catégories de clients les plus porteuses.
==============================================================*/

/* 4.1 Segmentation en fonction du nombre de commandes */

WITH nb_commandes AS (
	SELECT 
		fid.categorie_client, 
        SUM(f.total_sales) AS total_sales, 
        SUM(f.profit) AS profit, 
        fid.customer_id
	FROM 
		fidelite_clientele AS fid
	INNER JOIN 
		df_facts AS f
        ON fid.customer_id = f.customer_id
    GROUP BY 
		customer_id,
        categorie_client
)

SELECT
	categorie_client,
    COUNT(customer_id) AS nb_clients,
    SUM(total_sales) AS chiffre_affaires,
	ROUND(
		AVG(total_sales)
        ,2) AS ca_moyen_par_client,
	SUM(profit) AS profit_total,
	ROUND(
		AVG(profit)
        ,2) AS profit_moyen_par_client
FROM 
	nb_commandes
GROUP BY 
	categorie_client
ORDER BY 
	profit_moyen_par_client DESC;
    

/* ----- Interprétation -----
On constate une corrélation positive entre CA cumulé moyen, profit cumulé moyen et nombre de commandes passées. Ceci suggère que mettre en place une stratégie de rétention
efficace permettra d'augmenter la valeur générée par la clientèle.
 -------------------------- */

/* 4.2 Segmentation en fonction de l'activité */

SELECT 
	c.segment,
    COUNT(DISTINCT c.customer_id) AS nb_clients,
    SUM(f.quantity) AS volume_ventes,
    SUM(f.total_sales) AS chiffre_affaires,
	ROUND(
		SUM(f.total_sales) / COUNT(DISTINCT c.customer_id)
        ,2) AS ca_moyen_par_client,
	SUM(profit) AS profit_total,
	ROUND(
		SUM(f.profit) / COUNT(DISTINCT c.customer_id)
        ,2) AS profit_moyen_par_client
FROM 
	df_facts AS f
INNER JOIN 
	df_dim_customer AS c
    ON f.customer_id = c.customer_id
GROUP BY 
	c.segment
ORDER BY 
	profit_moyen_par_client DESC;

/* ----- Interprétation -----
Les particuliers représentent le plus gros segment de la clientèle mais un CA et un profit par client le plus bas.
Au contraire, les personnes travaillant à domicile sont les moins nombreuses mais les plus profitables. Ainsi, il peut être pertinent de mettre en place des moyens 
afin d'attirer et fidéliser ce segment.
 -------------------------- */

/*==============================================================
  5. ANALYSE PRODUIT
  Objectif : 
  Renseigner sur les performances des différentes catégories 
  de produit et identifier les produits les plus profitables.
==============================================================*/
    
/* 5.1 Performances par catégorie */

SELECT 
	category, 
    SUM(quantity) AS volume_ventes,
    SUM(total_sales) AS chiffre_affaires,
	ROUND(
		SUM(total_sales) 
        / 
        COUNT(DISTINCT order_id)
        ,2) AS ca_moyen_par_commande,
	ROUND(
		SUM(total_sales) 
        / 
        SUM(quantity)
        ,2) AS ca_moyen_par_unite,
	SUM(profit) AS profit_total,
	ROUND(
		SUM(profit) 
        / 
        COUNT(DISTINCT order_id)
        ,2) AS profit_moyen_par_commande,
	ROUND(
		SUM(profit) 
        / 
        SUM(quantity)
        ,2) AS profit_moyen_par_unite,
	ROUND(
		SUM(profit) 
        / 
        SUM(total_sales) * 100
        ,2) AS taux_marge
FROM 
	sales_details_product
GROUP BY 
	category
ORDER BY 
	profit_total DESC;
    

/* ----- Interprétation -----
La marge moyenne dégagée par les produits de la catégorie Furniture est particulièrement basse comparée aux marges des deux autres catégories.
 -------------------------- */
    
/* 5.2 Performances par sous-catégorie */ 

SELECT 
	sub_category, 
    category,
    SUM(quantity) AS volume_ventes,
	ROUND(
		SUM(total_sales) 
        / 
        COUNT(DISTINCT order_id)
        ,2) AS ca_moyen_par_commande,
	ROUND(
		SUM(total_sales) 
        / 
        SUM(quantity)
        ,2) AS ca_moyen_par_unite,
	ROUND(
		SUM(profit) 
        / 
        COUNT(DISTINCT order_id)
        ,2) AS profit_moyen_par_commande,
	ROUND(
		SUM(profit) 
        / 
        SUM(quantity)
        ,2) AS profit_moyen_par_unite,
	ROUND(
		SUM(profit) 
        / 
        SUM(total_sales) * 100
        ,2) AS taux_marge
FROM 
	sales_details_product
GROUP BY 
	sub_category,
    category
ORDER BY 
	taux_marge DESC;

/* ----- Interprétation -----
Les sous-catégories Bookcases et Tables générent des pertes malgré des CA moyens, par commande et par unité, parmi les plus élevés.
Les deux autres sous-catégories appartenant au groupe Furniture sont parmi celles ayant les marges les plus basses. 
 -------------------------- */
    
/* 5.3 Top 20 des produits les plus profitables */

SELECT 
	product_id,
	product_name,
    category, 
    sub_category,
	COUNT(DISTINCT order_id) AS nb_commandes,
	SUM(total_sales) AS chiffre_affaires,
    SUM(quantity) AS volume_ventes,
    SUM(profit) AS profit_total,
    SUM(profit)
	/
    SUM(total_sales) AS taux_marge
FROM 
	sales_details_product
GROUP BY 
	product_id,
    product_name,
    category, 
    sub_category
ORDER BY 
	profit_total DESC
LIMIT 
	20;

/* ----- Interprétation -----
Parmi les 20 produits dégageant le plus de profit, 14 sont dans la catégorie Technology, 6 dans Office Supplies et 0 dans Furniture.
 -------------------------- */


/*==============================================================
  6. ANALYSE CATEGORIE FURNITURE
  Objectif : 
  Identifier la ou les causes de la marge très faible dégagée
  par les ventes des produits de la catégorie Furniture.
==============================================================*/

/* 6.1 Cause testée : répartition différente selon la catégorie client */

SELECT
    p.category,
	SUM(fid.categorie_client = "Ponctuel") AS achat_ponctuel,
    SUM(fid.categorie_client = "Ponctuel") / COUNT(*) * 100 AS pct_achat_ponctuel,
	SUM(fid.categorie_client = "Régulier") AS achat_regulier,
    SUM(fid.categorie_client = "Régulier") / COUNT(*) * 100 AS pct_achat_regulier,
    SUM(fid.categorie_client = "Fidèle") AS achat_fidele,
    SUM(fid.categorie_client = "Fidèle") / COUNT(*) * 100 AS pct_achat_fidele
FROM 
	sales_details_product AS p
INNER JOIN 
	fidelite_clientele AS fid
    ON p.customer_id = fid.customer_id
GROUP BY 
    p.category;

SELECT
	p.category,
    p.sub_category,
	SUM(fid.categorie_client = "Ponctuel") AS achat_ponctuel,
    SUM(fid.categorie_client = "Ponctuel") / COUNT(*) * 100 AS pct_achat_ponctuel,
	SUM(fid.categorie_client = "Régulier") AS achat_regulier,
    SUM(fid.categorie_client = "Régulier") / COUNT(*) * 100 AS pct_achat_regulier,
    SUM(fid.categorie_client = "Fidèle") AS achat_fidele,
    SUM(fid.categorie_client = "Fidèle") / COUNT(*) * 100 AS pct_achat_fidele
FROM 
	sales_details_product AS p
INNER JOIN 
	fidelite_clientele AS fid
    ON p.customer_id = fid.customer_id
WHERE
	category = "Furniture"
GROUP BY 
	p.category,
    p.sub_category;

/* ----- Interprétation -----
Ces produits ne sont ni plus ni moins achetés par des clients réguliers ou fidèles que ceux des autres gammes.
 -------------------------- */
 
 /* 6.2 Cause testée : répartition différente selon l'année  */
 
   SELECT
    p.category,
	SUM(YEAR(f.order_date) = 2014) AS achat_2014,
    SUM(YEAR(f.order_date) = 2014) / COUNT(*) * 100 AS pct_achat_2014,
	SUM(YEAR(f.order_date) = 2015) AS achat_2015,
    SUM(YEAR(f.order_date) = 2015) / COUNT(*) * 100 AS pct_achat_2015,
	SUM(YEAR(f.order_date) = 2016) AS achat_2016,
    SUM(YEAR(f.order_date) = 2016) / COUNT(*) * 100 AS pct_achat_2016,
	SUM(YEAR(f.order_date) = 2017) AS achat_2017,
    SUM(YEAR(f.order_date) = 2017) / COUNT(*) * 100 AS pct_achat_2017
FROM 
	sales_details_product AS p
INNER JOIN 
	df_facts AS f
    ON p.order_id = f.order_id
GROUP BY 
    p.category;

/* ----- Interprétation -----
On n'observe pas de différence marquée dans la répartition temporelle des catégories.
 -------------------------- */
    
 /* 6.3 Cause testée : répartition différente selon la région  */
 
  SELECT
    p.category,
	SUM(l.region = "East") AS achat_east,
    SUM(l.region = "East") / COUNT(*) * 100 AS pct_achat_east,
	SUM(l.region = "South") AS achat_south,
    SUM(l.region = "South") / COUNT(*) * 100 AS pct_achat_south,
	SUM(l.region = "Central") AS achat_central,
    SUM(l.region = "Central") / COUNT(*) * 100 AS pct_achat_central,
	SUM(l.region = "West") AS achat_west,
    SUM(l.region = "West") / COUNT(*) * 100 AS pct_achat_west
FROM 
	sales_details_product AS p
INNER JOIN 
	sales_details_location AS l
    ON p.order_id = l.order_id
GROUP BY 
    p.category;

/* ----- Interprétation -----
On n'observe pas de différence marquée dans la répartition géographique des catégories.
 -------------------------- */

/* 6.4 Cause testée : impact des réductions */

SELECT 
	category, 
	COUNT(*) AS nb_achats, 
    SUM(discount > 0) AS nb_reductions, 
    ROUND( 
		SUM(discount > 0) 
        / 
        COUNT(*) * 100, 2) AS pct_achats_avec_remise, 
	ROUND( 
		AVG( 
			IF(discount > 0, discount, NULL) 
		) * 100 
	,2) AS reduction_moyenne, 
    ROUND( 
		SUM( 
			IF(discount > 0, total_sales, NULL)
		) 
		/
		SUM(total_sales) * 100
	, 2) AS pct_ca_avec_remise,
    SUM(profit) AS profit,
	ROUND( 
		SUM( 
			IF(discount = 0, profit, NULL)
		) 
	, 2) AS profit_sans_remise,
	ROUND( 
		SUM( 
			IF(discount > 0, profit, NULL)
		) 
	, 2) AS profit_avec_remise 
FROM 
	sales_details_product 
GROUP BY 
	category
ORDER BY 
	profit DESC; 

/* ----- Interprétation -----
La catégorie Furniture est celle dont les ventes sont le plus souvent faites avec une réduction. 
Près de deux-tiers du CA réalisés par cette gamme l'est lors d'offres promotionnelles.
Les ventes avec remise entrainent des pertes très importantes au regard des profits générés par celles sans remise.
 -------------------------- */

SELECT 
	category, 
    sub_category,
	COUNT(*) AS nb_achats, 
    SUM(discount > 0) AS nb_reductions, 
    ROUND( 
		SUM(discount > 0) 
        / 
        COUNT(*) * 100, 2) AS pct_achats_avec_remise, 
	ROUND( 
		AVG( 
			IF(discount > 0, discount, NULL) 
		) * 100 
	,2) AS reduction_moyenne, 
    ROUND( 
		SUM( 
			IF(discount > 0, total_sales, NULL)
		) 
		/
		SUM(total_sales) * 100
	, 2) AS pct_ca_avec_remise,
    SUM(profit) AS profit,
	ROUND( 
		SUM( 
			IF(discount = 0, profit, NULL)
		) 
	, 2) AS profit_sans_remise,
	ROUND( 
		SUM( 
			IF(discount > 0, profit, NULL)
		) 
	, 2) AS profit_avec_remise 
FROM 
	sales_details_product 
WHERE
	category = "Furniture"
GROUP BY 
	category,
    sub_category
ORDER BY 
	profit DESC; 

/* ----- Interprétation -----
Au sein de la gamme Furniture, les sous-catégories Bookcases et Tables sont déficitaires. 
 -------------------------- */
 

 WITH categorie_remise AS (
	SELECT 
		CASE 
			WHEN discount = 0 THEN " 0 - 0"
			WHEN discount*100 BETWEEN 0.001 AND 9.999 THEN "1 - ]0, 10["
            WHEN discount*100 BETWEEN 10 AND 19.999 THEN "2 - [10, 20["
            WHEN discount*100 BETWEEN 20 AND 29.999 THEN "3 - [20, 30["
			WHEN discount*100 BETWEEN 30 AND 39.999 THEN "4 - [30, 40["
            ELSE "5 - >= 40"
		END AS intervalle_remise_en_pct,
        total_sales,
        profit, 
        category, 
        sub_category
	FROM
		sales_details_product
)

SELECT 
	intervalle_remise_en_pct,
	SUM(category = "Furniture") AS nb_commandes_furniture,
	SUM(
		IF(category = "Furniture", profit, NULL)
	)
    /
    SUM(
		IF(category = "Furniture", total_sales, NULL)
	) AS taux_marge_furniture,
    SUM(category = "Technology") AS nb_commandes_technology,
	SUM(
		IF(category = "Technology", profit, NULL)
	)
    /
    SUM(
		IF(category = "Technology", total_sales, NULL)
	) AS taux_marge_technology,
    SUM(category = "Office Supplies") AS nb_commandes_office_supplies,
	SUM(
		IF(category = "Office Supplies", profit, NULL)
	)
    /
    SUM(
		IF(category = "Office Supplies", total_sales, NULL)
	) AS taux_marge_office_supplies
FROM 
	categorie_remise
GROUP BY 
	intervalle_remise_en_pct
ORDER BY 
	intervalle_remise_en_pct;

/* ----- Interprétation -----
Le taux de marge de la gamme Furniture est particulièrement impacté par l'augmentation de la remise effectuée. Celles-ci sont fréquentes ce qui peut expliquer le très faible
taux de marge moyen observé plus haut. 
Les réductions dans la catégorie Technology entrainent également une diminution du taux de marge mais il reste positif sauf lorsqu'elles dépassent les 40%. De plus, bien que 
majoritaire, elles sont principalement concentrées entre 20 et 30% où le taux de marge est encore de 14% en moyenne. 
Concernant la catégorie Office Supplies, les réductions de plus de 40%, qui sont présentes dans plus d'une commande sur 10, génèrent un taux de marge de -120%.
 -------------------------- */


    
/*==============================================================
  7. RESUME
==============================================================*/

/* Analyse temporelle 
Une activité en expansion sur la période 2015-2017.
Les meilleurs résultats sont obtenus entre septembre et décembre et les moins bons en janvier et février. 

/* Analyse géographique 
Les états de Californie et New York représentent 50% des profits. 

/* Analyse client 
Nombre de commandes, CA moyen et profit moyen sont positivement corrélés. Plus un client passe de commande, plus ils générent un CA et un profit élevés. 

/* Analyse produit
Une marge de 2% pour la catégorie Furniture quand elle est d'environ 17% pour les deux autres catégories.
Dans cette gamme, les sous-catégories Tables et Bookcases affichent des pertes nettes, Chairs et Furnishings des marges positives mais parmi les plus basses.
Ceci semble être dû à une fréquence importante des réductions dans cette catégorie. 
*/

/*==============================================================
  8. RECOMMANDATIONS
==============================================================*/

/*
1. Revoir la politique de remise de la catégorie Furniture
2. De manière générale, réaliser une revue complète des réductions de plus de 40%
3. Interroger la pertinence de la conservation des catégories Bookcases et Tables dans le catalogue
4. Adapter la gestion des stocks à la forte saisonnalité de l'activité
*/
