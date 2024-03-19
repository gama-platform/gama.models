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
		create a number:10;
	}
	
}

species a {
	
	point destination <- any_location_in(world.shape)+{0,0,rnd(100)};
	float speed <- 0.2;
	geometry shape <- sphere(2);
	
	rgb color <- #teal update:blend(#teal,#salmon,location.z/100);
	
	reflex move {		
		location <- {(1-speed) * location.x,(1-speed) * location.y, (1-speed) * location.z} + 
						{speed * destination.x, speed * destination.y, speed * destination.z};
						
		if location distance_to destination < 1#m { 
			destination <- any_location_in(world.shape)+{0,0,rnd(100)};
		}
	}
	
	aspect default {
		draw shape color:color;
		draw line(location,destination) color:color;
		draw pyramid(1) at:destination color:#yellow;
	}
	
}


experiment xp {
	float minimum_cycle_duration <- 0.1;
	output {
		display main type:3d {
			camera 'default' location: {130.2864,191.9952,158.8495} target: {37.2919,30.924,0.0};
			species a;
		}
	}
	
}