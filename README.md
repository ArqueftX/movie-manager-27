# Movie Manager 2027

Un jeu de gestion pour PC où vous dirigez votre propre studio de cinéma :
achetez des scénarios, engagez réalisateurs et stars, tournez vos films,
choisissez la bonne date de sortie et battez les studios rivaux au box-office.

Le jeu est fait avec **Godot 4** (moteur de jeu gratuit) et en **GDScript**.
Tous les noms de films, de studios et d'acteurs sont inventés.

## Jouer

- **Avec le .exe** : double-cliquez sur `MovieManager2027.exe`. Rien à installer.
- **Depuis le code** : installez [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)
  (version « Standard »), ouvrez Godot, cliquez sur « Importer » et choisissez le fichier
  `project.godot` de ce dossier. Appuyez ensuite sur **F5** pour lancer le jeu.

## Ce qu'on peut faire dans le jeu

| Onglet | À quoi il sert |
| --- | --- |
| Tableau de bord | Vos finances, la mode du moment, et des conseils sur quoi faire ensuite |
| Scénarios | Acheter des scénarios (genre, qualité, nombre de rôles, prix) |
| Talents | Tous les réalisateurs et acteurs : talent, célébrité, cachet, disponibilité |
| Productions | **Créer un film** : scénario + réalisateur + acteurs + budget, puis suivre le tournage et choisir la sortie |
| Box-office | Le classement des films de la semaine et l'historique de vos films |
| Studio | Améliorations (plateaux, montage, effets spéciaux, marketing, scénaristes) et banque |
| Concurrents | Le classement des studios et les prochaines sorties des rivaux |
| Aide | Les règles expliquées simplement |

Un film passe par : préproduction → tournage (avec des imprévus et des décisions à prendre)
→ post-production → sortie au cinéma. Le box-office dépend de la qualité, de la célébrité du
casting, de la publicité, de votre réputation, de la saison et de la concurrence.

La partie est sauvegardée automatiquement toutes les 4 semaines de jeu.

## Organisation du code

```
project.godot          configuration du projet Godot
scenes/main.tscn       la scène principale (vide : l'interface est créée en code)
scripts/data.gd        les données fixes : genres, prix, noms, améliorations...
scripts/game_state.gd  les règles du jeu et la partie en cours (chargé sous le nom "Game")
scripts/main.gd        l'interface : un fichier, une fonction par onglet
tests/test_runner.tscn un "joueur robot" qui joue 10 ans pour vérifier que rien ne plante
```

Pour changer l'équilibrage (prix, durées, bonus), commencez par `scripts/data.gd`.

## Créer le .exe soi-même

Dans Godot : menu **Projet → Exporter…**, choisissez le préréglage « Windows »,
puis **Exporter le projet**. Godot propose de télécharger les « modèles d'export » la
première fois : acceptez.

## Lancer le test automatique

```
godot --headless --path . res://tests/test_runner.tscn
```
