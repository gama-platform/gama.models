/**
* Name: Actionsvsreflex
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model Actionsvsreflex

global {
	init {
		create species1 number: 2;
	}
	
	reflex execution {
		ask shuffle(species1) {
			do action_debut;
		}
		ask shuffle(species1) {		
			do action_fin;
		}		
	}
}

species species1 {
	action action_debut {
		write "" + self + " REFLEX action_debut";
	}
	action action_fin {
		write "" + self + " REFLEX action_fin";
	}
}

experiment name type: gui { }