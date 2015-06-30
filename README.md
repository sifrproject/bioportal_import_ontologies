# bioportal_import_ontologies
Ruby scripts to import ontologies from BioPortal or cropontology.org to a BioPortal Appliance

This script is using 2 files : config.rb (see config.rb.sample) and import_array.json (see import_array.json.sample)

* config.rb contains informations to connect to the appliance (appliance URL, apikey, user that will upload the ontologies)
* import_array.json contains the informations of the ontologies to be uploaded

All informations about ontologies to be imported are in "import_array.json"
The "source" indicate from where the array is imported. There are 2 available sources at the time : ncbo_bioportal and cropontology.
For ncbo_bioportal the ontology is uploaded using a pullLocation and it imports also all the ontology metadata from data.bioontology.org, excepted the groups and categories.
But for cropontology the ontology is first downloaded on the machine and then added using uploadFilePath (so if you to import data from cropontology.org you need to run it from the Appliance where you want to import it). And you have to give all the metadata in the JSON.
