/**
* Name: SimpleSIR2
* 
* Author: kevinchapuis
* Tags: 
*/


model SimpleSIR2

global {
	init {
		create people number:100;
	}
}

species people skills:[moving] {	
	
	reflex move {
		do wander;
	}
	
	aspect default {
		draw circle(1) color:#green;
	}
}

experiment Exp type: gui {
	output {
		display main {
			species people;
		}
	}
}

