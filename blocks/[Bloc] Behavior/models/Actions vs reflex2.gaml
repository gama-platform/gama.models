/**
* Name: Actionsvsreflex
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model Actionsvsreflex

global {
	init {
		create people number: 2;
	}
}

species people {
	reflex base {
		write "" + self + " REFLEX base";
	}
	reflex base2 {
		write "" + self + " REFLEX base2";
	}
	
	action msg {
		write "" + self + " ACTION message";	
	}
	action msg2 {
		write "" + self + " ACTION message2";	
	}
	
}



experiment name type: gui { }