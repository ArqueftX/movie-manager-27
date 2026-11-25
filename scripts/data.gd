# Données fixes du jeu : genres, noms, titres, améliorations...
# Tout est inventé : aucun nom ne vient d'un vrai film ou d'un vrai studio.
extends RefCounted

const GENRES := ["Action", "Comédie", "Drame", "Horreur", "Science-fiction", "Animation", "Romance", "Thriller"]

# Taille du public de chaque genre (1.0 = moyenne).
const GENRE_BASE := {
	"Action": 1.25, "Comédie": 1.0, "Drame": 0.75, "Horreur": 0.85,
	"Science-fiction": 1.2, "Animation": 1.15, "Romance": 0.8, "Thriller": 0.95,
}

# Durée du tournage (en semaines) selon le genre.
const SHOOT_WEEKS := {
	"Action": 9, "Comédie": 6, "Drame": 6, "Horreur": 5,
	"Science-fiction": 10, "Animation": 12, "Romance": 5, "Thriller": 7,
}

# Genres qui profitent du studio d'effets spéciaux.
const VFX_GENRES := ["Action", "Science-fiction", "Animation", "Horreur"]

const PREPROD_WEEKS := 3
const BASE_POSTPROD_WEEKS := 5

const PROD_LEVELS := [
	{"name": "Petit budget", "weekly": 250000.0, "bonus": 0, "hype": 0},
	{"name": "Standard", "weekly": 700000.0, "bonus": 6, "hype": 5},
	{"name": "Superproduction", "weekly": 1800000.0, "bonus": 12, "hype": 15},
]

const MKT_LEVELS := [
	{"name": "Sans publicité", "cost": 0.0, "hype": 0},
	{"name": "Campagne nationale", "cost": 2500000.0, "hype": 20},
	{"name": "Campagne massive", "cost": 7000000.0, "hype": 40},
]

# Améliorations du studio. "costs[n]" = prix pour passer du niveau n au niveau n+1.
const UPGRADES := {
	"plateaux": {
		"name": "Plateaux de tournage", "min": 1, "max": 4,
		"costs": [0.0, 3000000.0, 6000000.0, 12000000.0],
		"desc": "Chaque plateau permet de produire un film de plus en même temps.",
	},
	"ecriture": {
		"name": "Bureau des scénaristes", "min": 0, "max": 3,
		"costs": [1500000.0, 3000000.0, 6000000.0],
		"desc": "Plus de scénarios à vendre, et de meilleure qualité.",
	},
	"montage": {
		"name": "Salle de montage", "min": 0, "max": 3,
		"costs": [2000000.0, 4000000.0, 8000000.0],
		"desc": "Post-production plus rapide (-1 semaine) et films meilleurs (+2 qualité) par niveau.",
	},
	"vfx": {
		"name": "Studio d'effets spéciaux", "min": 0, "max": 3,
		"costs": [3000000.0, 6000000.0, 12000000.0],
		"desc": "+3 qualité par niveau pour l'action, la science-fiction, l'animation et l'horreur.",
	},
	"marketing": {
		"name": "Département marketing", "min": 0, "max": 3,
		"costs": [2000000.0, 4000000.0, 8000000.0],
		"desc": "Les campagnes de publicité sont 20 % plus efficaces par niveau.",
	},
}

const RIVAL_NAMES := ["Lumière Noire Pictures", "Comète Studios", "Atlas Films Group"]

const FIRST_NAMES := [
	"Léa", "Hugo", "Chloé", "Lucas", "Manon", "Nathan", "Camille", "Théo", "Inès", "Jules",
	"Sarah", "Maxime", "Emma", "Louis", "Jade", "Adam", "Alice", "Raphaël", "Zoé", "Gabriel",
	"Nina", "Victor", "Lina", "Arthur", "Eva", "Sacha", "Clara", "Malik", "Yasmine", "Diego",
	"Sofia", "Kenji", "Amara", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Mila", "Elias",
	"Margot", "Bastien", "Anaïs", "Romain", "Salomé", "Kylian", "Rose", "Idris", "Maëlys", "Oscar",
]

const LAST_NAMES := [
	"Moreau", "Laurent", "Girard", "Fontaine", "Rousseau", "Blanchard", "Mercier", "Garnier",
	"Chevalier", "Lambert", "Faure", "Bonnet", "Dupuis", "Marchand", "Renard", "Carver",
	"Holloway", "Brennan", "Whitmore", "Castillo", "Okafor", "Tanaka", "Lindqvist", "Novak",
	"Ferreira", "Ashford", "Delacroix", "Valdez", "Kowalski", "Sterling", "Benali", "Roussel",
	"Perrin", "Morel", "Diallo", "Sauvage", "Leclerc", "Vidal", "Hartmann", "Moreno",
]

# Les titres sont fabriqués en assemblant un début et une fin selon le genre.
const TITLE_PARTS := {
	"Action": [
		["Opération", "Code", "Vengeance", "Impact", "Frontière", "Protocole", "Mission", "Assaut"],
		["Fantôme", "Rouge", "Zéro", "Ultime", "de Fer", "Noire", "Tempête", "Cobra"],
	],
	"Comédie": [
		["Mon voisin", "Les vacances de", "Le mariage de", "Le tonton de", "Panique chez", "Bienvenue chez", "Le camping de", "Les bêtises de"],
		["Gérard", "la famille Dupuis", "Mamie Jo", "Robert", "les Martin", "Bernard", "tante Lulu", "Jean-Mi"],
	],
	"Drame": [
		["Les silences de", "Après", "La lettre de", "Le dernier été à", "Ce que savait", "Les racines de", "Loin de", "Le pardon de"],
		["Margaux", "l'hiver", "Saint-Malo", "notre père", "Clara", "la rivière", "Lisette", "la mer"],
	],
	"Horreur": [
		["La maison de", "Les murmures de", "Ne réveillez pas", "Le sous-sol de", "La nuit de", "L'écho de", "Le grenier de", "La malédiction de"],
		["Blackwood", "l'ombre", "la poupée", "minuit", "Saint-Ange", "la forêt", "Grand-Mère", "Hollow Creek"],
	],
	"Science-fiction": [
		["Horizon", "Station", "Orbite", "Les enfants de", "Projet", "Nébuleuse", "Colonie", "Signal"],
		["Kepler", "Andromède", "Titan", "Oméga", "2099", "Hélios", "Proxima", "Europa"],
	],
	"Animation": [
		["Les aventures de", "Pipo et", "Le royaume de", "Mission", "Le petit monde de", "Capitaine", "Le voyage de", "Le secret de"],
		["Biscotte", "le dragon", "Noisette", "Pinpin", "Lumi", "les nuages", "Plume", "Moustache"],
	],
	"Romance": [
		["Un été avec", "Rendez-vous à", "Tout contre", "Les lettres de", "Coup de foudre à", "Juste", "Deux billets pour", "Un hiver à"],
		["toi", "Lisbonne", "Venise", "Léa", "Montmartre", "un regard", "Biarritz", "Naples"],
	],
	"Thriller": [
		["Le témoin de", "Les secrets de", "L'affaire", "Sans issue à", "Le complot de", "Dernier appel pour", "La disparue de", "Le silence de"],
		["Marseille", "la gare du Nord", "Kessler", "Lyon", "Nora", "l'avocat", "Brest", "Val-d'Or"],
	],
}

const MONTHS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
