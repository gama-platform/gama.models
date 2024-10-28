/**
* Name: Schelling
* Author: bgaudou
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model Schelling2

global {	
	
	int envsize <- 50;
	geometry shape <- square(envsize);
	float emptyprop <- 0.1;
	
	float redprop <- 0.5;
	float theta <- 0.5;
	
	init {
		create people number: envsize^2 - (envsize^2*emptyprop) {
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

grid loc height: envsize width: envsize neighbors:8 { people p; }

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
		draw circle(world.shape.width/(envsize*2)) color: color;
	}
}

experiment exp type: gui {
	
	parameter size var:envsize min:10 max:200;
	parameter empty var:emptyprop min:0 max:0.9;
	parameter groups var:redprop min:0 max:1 colors:[#red,#blue];
	parameter threshold var:theta min:0 max:1;
	
	output {
		display d type:2d {
			grid loc lines:#black;
			species people;
		}
		display sat type:2d {
			chart "satisfaction" type:series {
				data "overall satisfaction" value:people count each.satisfied;
			}
		}
	}
}