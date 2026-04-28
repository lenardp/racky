# Project intent

*Initial Prompt/context for Claude Code to read*

The goal of this project is a simple app called Racky that stores images of a user's
garments and suggest outfits based on those garments.

Outfit suggestion is basically based on the following principles:
* **High cohesion** - most/all pieces have a lot in common
* **A little POP** - Some pieces sharply stand out

## For inspiration

see the previous attempt at making Racky, at ../racky-old/

## High level architecture

It is to be a small ecosystem of event-driven microservices.

I'm thinking:
* Made of Ruby on Rails, Node.js, React.js, Kafka, Claude, MySQL and maybe AWS S3?
* Microservice called **racky-gateway** - A lean API Gateway in front of everything.
  * Made of Node.js
  * All Racky HTTP requests are to the API gateway
* Microservice called **racky-lookbook** - react.js frontend
* Microservice called **racky-tagger** - for talking to Claude API to tag garments
  * made of python (django?)
* "Microservice" called **racky-monolith**
  * made of ruby on rails with mysql db
  * especially for storing garment data and generating outfits, but also authentication and whatever else
  * honestly this isn't actually very micro since I think it doesn't make much sense to put user authentication data anywhere else... right?
  * I'm going off the principal of "go monolith for speed, but split off as soon as you can".
    * this isn't really a monolith, but
  * should be structured such that outfit generation can be pulled into a separate service if we want.
* This is primarily an event-driven microservices architecture
* events implemented by kafka queues.  We'll start with two for now
  * one called "New Garments", and one called "Tagged Garments"
* each service is dockerized

## racky-gateway

* very lean and simple node.js app
* Endpoints:
  * /api/v1 - a REST API
    * /garments
      * POST
      * PUT
      * GET
      * DELETE
      * all directed to racky-closet
    * /outfits
      * /generate - Generates an outfit (not saved to db)
      * directed to racky-closet
  * /ping
  * Everything else
    * directed to racky-lookbook
* use Express and axios

## racky-lookbook

* I don't have too many opinions about react.js
* I remember Top Hat (tophatmonocle) had a react pattern called "ducks" or something
  * and they also used sagas
  * let's do that for this microservice
* see ../racky-old/racky-dover/ for code styling/formatting inspiration
* frontend components hit the API gateway of course
* should only have the following pages
  * login
  * home page that links to the garment upload and outfit generator
  * garment upload page (where user can take pics with their phone and upload it to racky)
  * outfit generator page

## racky-monolith

* instead of the typical ruby on rails directory structure, it divides the app into domains
  * so if anything should be split into another microservice, it should be easy to do
  * Domains should barelly use each other's classes, so they're easier to piece apart later.
* directory structure
  * apps/
    * closets/
      * controllers/
      * models/
      * services/
      * tests/
    * accounts/
      * controllers/
      * models/
      * services/
      * tests/
  * config/
  * lib/
  * db/
  * ...etc.  I just wanted to illustrate that apps should split controllers, models, tests, etc. by domain
* models
  * under closets/
    * Garment - a specific piece of clothing
      * id - a UUID
      * image_url - URL to an image of the garment.  nullable
      * name - nullable
      * layer - an integer 1-4 describing how you layer it with other pieces.  greater numbers go over lesser number
        * 1 - base or "under" layer, like a t-shirt, leggings, or rings
        * 2 - can be worn alone, or have a layer underneath, like a button-up or a dress
        * 3 - primarily for going over other layers, like jackets
        * 4 - outerwear only, like winter jackets
      * user_id - id of the user owning this
    * Tag - A word/term describing the garment, vibe-wise.  Examples
      * blue
      * cool-coloured
      * denim
      * americana
      * punk
      * formal
      * grunge
      * tiger-print
      * graphic-print
      * soft
      * oversized
      * techwear
      * 90's
      * basketball
      * streetwear
      * running
      * light
      * dark
      * tough
      * basic
    * TagContrast - join table between tags to show that these are in sharp contrast
      * light & dark
      * cool & warm
      * formal & casual
      * tough & soft
      * oversized & skinny
      * wide & narrow
    * GarmentTag - Join table between Garment and Tag to describe the vibe of a garment
    * BodyZoneGarment - Join table between BodyZone and Garment to show the parts of the body a garment would be worn over.
      * A dress would be worn over torso and legs, for example
    * BodyZone - body parts a garment can be worn over.  Rows:
      * torso
      * legs
      * feet
      * head
      * neck
      * hands
  * under accounts/
    * user
    * ...well it should be obvious from here.  you can fill that in, Claude.
* when `POST /api/v1/garments` triggers a call to racky-monolith, we should
  * create a Garment record for this User.
    * blank photo, layer and name for now
    * no tags nor body zones identified for now
  * pass all the given garment information into the "Untagged Garments" kafka queue
* Should also listen to the "Tagged Garments" kafka queue. each event would describe
  * a name for the garment
  * all tags that apply
  * what layer to apply to it
  * all body zones it is worn over
* Mysql database
* when `POST /api/v1/outfit/generate` triggers a call to racky-monolith, we should put together an outfit using the pieces in the user's wardrobe, using tags
  * (theoretically ai could do outfit generation as well, but i'm tryna save on tokens)
  * All pieces combined should cover at least the basics of the body:
    * torso has at least a layer 1 or 2
    * Legs have at least a layer 1 or 2
    * feet have at least a layer 2 (shoes).
  * **High cohesion** - There should be a lot of tags in common amongst garments
  * **A little POP** - a few tags have a TagContrast with the common tags
  * can add accessories to help with the high cohesion x little POP ratios
  * list all garments of the outfitin the response

## racky-tagger

* made of python (django?)
* stores a copy of the list of tags either as another db, or maybe a simple list file
* listens to the "Untagged Garments" queue for events.  when event received (with Garment information)
  * uploads photo of garment to S3
  * sends a prompt to claude which includes
    * photo of garment
    * asks for
      * layer number
      * tags that apply
      * body zones it is worn over
    * list of all possible tags for it to choose from
    * quick explanation of layer number
    * list of all possible body zones
    * asks for the response format to be in JSON
  * extracts that ^ info from the response.
  * sends the Garment's complete information down throught eh "Tagged Garment" kafka event queue.
