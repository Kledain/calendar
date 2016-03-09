# A propos de l'application Agenda

* licence : AGPL v3
* Développeur : ATOS
* financeur : Région Picardie, Conseil général 91, Région Poitou Charente
* description : Application agenda personnel et agenda partagé

# Documentation technique

## Construction

<pre>
		gradle copyMod
</pre>

## Déployer dans ent-core


## Configuration

Dans le fichier `/calendar/deployment/calendar/conf.json.template` :


Déclarer l'application dans la liste :
<pre>
{
  "name": "net.atos~calendar~0.2.0",
      "config": {
        "main" : "net.atos.entng.calendar.Calendar",
        "port" : 8098,
        "app-name" : "Calendar",
        "app-address" : "/calendar",
        "app-icon" : "calendar-large",
        "host": "${host}",
        "ssl" : $ssl,
        "userbook-host": "${host}",
        "integration-mode" : "HTTP",
        "app-registry.port" : 8012,
        "mode" : "${mode}",
        "entcore.port" : 8009
     }
}
</pre>

Associer une route d'entée à la configuration du module proxy intégré (`"name": "net.atos~calendar~0.2.0"`) :
<pre>
	{
		"location": "/calendar",
		"proxy_pass": "http://localhost:8098"
	}
</pre>

# Présentation du module

## Fonctionnalités

L’Agenda permet la création et la visualisation d’événements sous forme d’un calendrier ou d’une liste.

Des permissions sur les différentes actions possibles sur les agendas, dont la contribution et la gestion, sont configurées dans l'agenda (via des partages Ent-core).
Le droit de lecture, correspondant à qui peut consulter l'agenda est également configuré de cette manière.

## Modèle de persistance

Les données du module sont stockées dans deux collections Mongo :
 - "calendar" : pour toutes les données propres aux agendas
 - "calendarevent" : pour toutes les données propres aux évènements

## Modèle serveur

Le module serveur utilise 2 contrôleurs de déclaration :

* `CalendarController` : Point d'entrée à l'application, Routage des vues, sécurité globale et déclaration de l'ensemble des comportements relatifs aux agendas (liste, création, modification, destruction et partage)
* `EventController` : Sécurité des évènements et déclaration de l'ensemble des comportements relatifs aux évènements d'un agenda (création, modification, destruction, récupération et import ical)

Les contrôleurs étendent les classes du framework Ent-core exploitant les CrudServices de base. Pour des manipulations spécifiques, des classes de Service sont utilisées :

* `EventService` : Concernant les évènements de l'Agenda

Des jsonschemas permettent de vérifier les données reçues par le serveur, ils se trouvent dans le dossier "src/main/resources/jsonschema".

## Modèle front-end

Le modèle Front-end manipule 3 objets models :

* `Calendars` : Correspondant aux agendas
* `Calendar` : Correspondant à un agenda
* `CalendarEvent` : Correspondant aux évènements d'un agenda

Il y a 2 Collections globales :

* `model.calendars.all` qui contient l'ensemble des objets `calendar` synchronisé depuis le serveur.
* `model.calendarEvent.all` qui contient l'ensemble des objets `event` synchronisé depuis le serveur.