/**
* Name: InteractionFireSpread
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model InteractionFireSpread

/* Insert your model definition here */

global {
	
	init {
		
		ask ((length(plot) * 1) among plot) { state <- "forest"; color <- #green; }
		ask any(plot where (each.state = "forest")) { state <- "fire"; color <- #firebrick;}
	}
	
}

species a {}

grid plot width:100 height:100 schedules:shuffle(plot) neighbors:8 {
	
	rgb color <- #white;
	string state <- "clear";
	
	reflex spread when:(state="fire") {
		ask neighbors where (each.state="forest") {state <- myself.state; color <- myself.color;}
	}
	
}

experiment xp {
	output {
		display main {
			grid plot border:#black;
		}
	}
}