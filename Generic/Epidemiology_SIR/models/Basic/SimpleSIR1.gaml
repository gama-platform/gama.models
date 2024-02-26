/**
* Name: SimpleSIR1
* 
* Author: kevinchapuis
* Tags: 
*/

model SimpleSIR1

global {
	init {
		create people number:100;
	}
}

species people {	
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
