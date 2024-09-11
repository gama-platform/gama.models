/**
* Name: RobotForagerWG
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model RobotForagerWG

/* Insert your model definition here */

global {
	
	float surroundings <- 5#m; 
	
	init {
		create robot number:10;
		create ressource number:10;
	}
	
}

species robot skills:[moving] {
	
	reflex forage {
		
		ressource cls <- ressource closest_to self;
		if not(cls = nil) and cls distance_to self < surroundings {
			do goto target:cls;
			if location = cls.location {
				ask cls {do die;}
			}
		} else {
			do wander amplitude:90;
		}
		
	}
	
	aspect default {
		draw circle(surroundings).contour color:#black; 
		draw square(2) color:#blue;
	}
}

species ressource {
	aspect default { draw circle(1) color:#green; }
}

experiment xp {
	output {
		display main {
			species ressource;
			species robot;
		}
	}
}