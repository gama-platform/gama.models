/**
* Name: Actionsvsreflex
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model Actionsvsreflex

global schedules: shuffle(species1 + species2){
	init {
		create species1 number: 2;
		create species2 number: 2;		
	}
}

species species1 {
	reflex action_debut {
		write "" + self + " REFLEX action_debut";
	}
	reflex action_fin {
		write "" + self + " REFLEX action_fin";
	}
}

species species2 {
	reflex action_debut {
		write "" + self + " REFLEX action_debut 2";
	}
	reflex action_fin {
		write "" + self + " REFLEX action_fin 2";
	}
}


experiment name type: gui { }