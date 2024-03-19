/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Move

/* Insert your model definition here */

global {
	
	init {
		create a number:10 with:[current_location::any(g)] {location <- current_location;}
	}
	
}

species a {
	
	g current_location;
	g destination <- any(g);
	geometry shape <- circle(2);
	
	reflex move when:current_location!=destination {		
		current_location <- current_location.neighbors closest_to destination;
		location <- current_location;
	}
	
	aspect default {
		draw shape color:#teal;
		draw current_location color:blend(#purple,#transparent,0.6);
	}
	
}

grid g width:20 height:20 {}

experiment xp {
	output {
		display main type:2d {
			grid g border:#black;
			species a;
		}
	}
	
}