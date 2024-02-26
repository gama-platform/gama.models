/**
* Name: model1
* Based on the internal skeleton template. 
* Author: Patrick Taillandier
* Tags: 
*/

model model1

global {
	init {
		create intersection number: 10;
	}
}

species intersection {
	aspect default {
		draw square(1.0) color: #gray border: #black;
	}
}

experiment run_simulation type: gui {
	output {
		display map {
			species intersection;
		}
	}
}
