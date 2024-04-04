/**
* Name: perception1
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model perception1

/* Insert your model definition here */

global torus:true {  
	
	a caller;
	float perception <- 8;
	
	init {
		create a number:100 {do rndmove;}
		caller <- any(a);
	}
	
}

species a {
	
	g mycell;
	
	rgb color <- rnd_color(255);
	bool onsight -> (topology(g) neighbors_of (caller, perception)) contains self;
	
	reflex rndmove when:self!=caller { do rndmove; }
	
	action rndmove {
		mycell.occupant <- nil;
		mycell <- any(g where (each.occupant=nil));
		mycell.occupant <- self;
		location <- mycell.location;
	}
	
	aspect default {
		draw circle(1) color:blend(color,#transparent,onsight?1:0.1);
		if self=caller { draw union(topology(g) neighbors_of (mycell,perception)).contour+0.1 color:#firebrick; }
	}
	
}

grid g width:50 height:50 { a occupant <- nil; }

experiment xp { 
	float minimum_cycle_duration <- 0.1;
	output {
		display main {
			grid g lines:#black;
			species a;
		}
	}
}