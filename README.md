# bioportal_import_ontologies
Ruby scripts to import ontologies from differents sources (BioPortal, cropontology.org, any URL) to a BioPortal Appliance

This script is using 2 files : config.rb (see config.rb.sample) and import_array.json (see import_array.json.sample)

* config.rb contains informations to connect to the appliance (appliance URL, apikey, user that will upload the ontologies)
* import_array.json contains the informations of the ontologies to be uploaded. It is using the same field as the JSON BioPortal use to upload ontologies using the API.
We are using one additional key: "source" that allows to give the source of the ontology (bioportal, cropontology or others)

## Import ontologies from another BioPortal Appliance
You need to fill bp_url_input and bp_apikey_input with the URL of the BioPortal appliance you want to import ontologies from
Then in the JSON just give the acronym of the ontology you want to import and all the metadata will be imported from BioPortal. Except from the groups and category (you can fill it with yours)
Example (from [bioontology.org](http://bioportal.bioontology.org))

```json
{
    "acronym": "EDAM",
    "source": "bioportal",
    "group": [],
    "hasDomain": []
}
```

   
## Import ontologies from [cropontology.org](http://www.cropontology.org)
    
It is impossible to make a pullLocation on [cropontology.org](http://www.cropontology.org) so the file is automatically downloaded, uploaded to the server (in the /tmp directory using SCP) and then uploaded to the BioPortal Appliance.
In this case you have to fill the config.rb with server_hostname, server_username and server_password to allow SCP to upload the file.

All the ontologies informations have to be filled in the JSON, since it can't be imported. Use the "pullLocation" key to give the ontology URL. 

Here is an example of JSON used to upload a [cropontology.org](http://www.cropontology.org) ontology:
```json
{
    "acronym": "CO_321",
    "source": "cropontology",
    "group": [],
    "hasDomain": [],
    "name": "CGIAR Wheat Trait Ontology",
    "contact": [{"name": "Vincent Emonet", "email": "vincent.emonet@lirmm.fr"}],
    "hasOntologyLanguage": "OBO",
    "released": "2014-09-01",
    "description": "CIMMYT - Wheat - September 2014",
    "status": "beta",
    "version": "2014",
    "homepage": "http://www.cropontology.org/",
    "documentation": "http://www.cropontology.org/ontology/CO_321",
    "publication": "",
    "pullLocation": "http://www.cropontology.org/serve/AMIfv95LZkfqANx67WLKz1nPj0sKQ7LpdcHr3Y-uDlWm1vN4Y6opgXFxhuFK0vPf1mqSIYByzuNYQUADw8rX1hSlqHxCg4bSDJnDGCthZcRnO4ng_E7FKSsLlp6RR_Sog7xaguHAMs_v-FqpwVjvmYv7NOXqr3hSN2xFv9zXOacsBKnF00lo0wI"
}
```
    

## Import ontologies from any URL

You also can import an ontology from any URL using pullLocation

```json
{
    "acronym": "FALDO",
    "source": "url",
    "group": [],
    "hasDomain": [],
    "name": "Feature Annotation Location Description Ontology",
    "contact": [{"name": "Jerven Bolleman", "email": "jerven.bolleman@isb-sib.ch"}],
    "hasOntologyLanguage": "OWL",
    "prefLabelProperty": "http://www.w3.org/2000/01/rdf-schema#label",
    "definitionProperty": "http://www.w3.org/2000/01/rdf-schema#comment",
    "released": "2013-06-28",
    "description": "FALDO is the Feature Annotation Location Description Ontology. It is a simple ontology to describe sequence feature positions and regions as found in GFF3, DBBJ, EMBL, GenBank files, UniProt, and many other bioinformatics resources. The aim of this ontology is to describe the position of a sequence region or a feature. It does not aim to describe features or regions itself, but instead depends on resources such as the Sequence Ontology or the UniProt core ontolgy.",
    "status": "beta",
    "version": "2013",
    "homepage": "https://github.com/JervenBolleman/FALDO",
    "documentation": "https://github.com/JervenBolleman/FALDO",
    "publication": "",
    "pullLocation": "https://raw.githubusercontent.com/JervenBolleman/FALDO/master/faldo.ttl"
}
```