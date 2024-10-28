/**
* Name: Schelling3
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Schelling3

/* Insert your model definition here */

global {	
	
	shape_file buildings0_shape_file <- shape_file("../includes/buildings.shp");

	geometry shape <- envelope(buildings0_shape_file);
	float emptyprop <- 0.1;
	
	float redprop <- 0.5;
	float theta <- 0.5;
	
	float neighbor_distance <- 200#m;
	
	init {
		
		create loc from:buildings0_shape_file;
		ask loc { neighbors <- (loc - self) at_distance (neighbor_distance); }
		
		create people number: length(loc) * (1-emptyprop) {
			loc l <- world.find_empty_loc();
			location <- l;
			l.p <- self;
			color <- #red;
		}
		ask ((1-redprop) * length(people)) among people { color <- #blue; }
	}
	
	loc find_empty_loc { return shuffle(loc) first_with (each.p=nil); }
	
	reflex equilibrium when:people all_match (each.satisfied) {
		do pause;
	}
}

species loc {
	people p; 
	list<loc> neighbors;
	aspect default {draw shape color:blend(p.color,#transparent,0.5) border:#black;}
}

species people {
	rgb color;	
	
	bool satisfied <- false;
	
	reflex stayorleave {
		list<people> n <- loc[location.x,location.y].neighbors where (each.p != nil) collect (each.p);
		float mixture <- empty(n) ? 0.0 : n count (each.color=color) / length(n);
		if theta > mixture { 
			satisfied <- false; 
			do move();
		} else {
			satisfied <- true;
		}
	}
	
	action move {
		loc l <- world.find_empty_loc();
		loc[location.x,location.y].p <- nil;
		location <- l;
		l.p <- self;
	}
	
	aspect default { 
		draw circle(2) color: color;
	}
}

experiment exp type: gui {
	
	parameter empty var:emptyprop min:0 max:0.9;
	parameter groups var:redprop min:0 max:1 colors:[#red,#blue];
	parameter threshold var:theta min:0 max:1;
	
	parameter proximity var:neighbor_distance min:100#m max:1#km;
	
	output {
		display d type:2d {
			species loc;
			species people;
		}
		display sat type:2d {
			chart "satisfaction" type:series {
				data "overall satisfaction" value:people count each.satisfied;
			}
		}
	}
}