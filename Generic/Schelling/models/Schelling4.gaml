/**
* Name: Schelling
* Author: bgaudou
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model Schelling4

global {	
	
	shape_file buildings0_shape_file <- shape_file("../includes/buildings.shp");

	geometry shape <- envelope(buildings0_shape_file);
	float emptyprop <- 0.1;
	
	float redprop <- 0.5;
	float theta <- 0.5;
	
	float neighbor_distance <- 200#m;
	
	bool surrounding_building <- true;
	bool own_building <- true;
	
	init {
		create building from:buildings0_shape_file {
			flat_number <- max(1,shape.area / 300) * rnd(1,5);
			float inhabit_number <- int(flat_number*(1-emptyprop));
			if flat_number = inhabit_number {error "should not be the same";} 
			create people number:inhabit_number returns:residents{
				myloc <- myself;
				location <- any_location_in(myloc);
				color <- #red;
			}
			inhabitants <- residents;
		}
		
		ask building { neighbors <- (building - self) at_distance (neighbor_distance); }
		
		ask ((1-redprop) * length(people)) among people { color <- #blue; }
	}
	
	building find_empty_loc { return shuffle(building) first_with (length(each.inhabitants) < each.flat_number); }
	
	reflex equilibrium when:people all_match (each.satisfied) {
		do pause;
	}
}

species building {
	int flat_number;
	 
	list<building> neighbors;
	list<people> inhabitants;
	
	float mixture(rgb color) { 
		return empty(inhabitants) ? 0.0 : inhabitants count (each.color=color) / length(inhabitants);
	}
	
	aspect default {
		draw shape color:empty(inhabitants) ? #white : blend(#red,#blue,inhabitants count (each.color=#red) / length(inhabitants)) 
			border:#black;
	}
}

species people {
	rgb color;	
	
	bool satisfied <- false;
	building myloc;
	
	reflex stayorleave {
		float bmix <- myloc.mixture(color);
		float nmix <- mean(myloc.neighbors collect (each.mixture(color)));
		float mix <- own_building ? 
					(surrounding_building ? (bmix+nmix)/2 : bmix) : 
					(surrounding_building ? nmix : (rnd(2.0)+bmix+nmix)/4); 
		if theta > mix { 
			satisfied <- false; 
			do move();
		} else {
			satisfied <- true;
		}
	}
	
	action move {
		building b <- world.find_empty_loc();
		myloc.inhabitants >- self;
		b.inhabitants <+ self;
		myloc <- b;
		location <- any_location_in(myloc);
	}
	
	aspect default { 
		draw circle(2) color: color border:#black;
	}
}

experiment exp type: gui {
	
	parameter empty var:emptyprop min:0 max:0.9;
	parameter groups var:redprop min:0 max:1 colors:[#red,#blue];
	parameter threshold var:theta min:0 max:1;
	
	parameter surroundings var:surrounding_building;
	parameter proximity var:neighbor_distance min:100#m max:1#km;
	
	parameter own_building var:own_building;
	
	output {
		display d type:2d {
			species building;
			species people;
		}
		display sat type:2d {
			chart "satisfaction" type:series {
				data "overall satisfaction" value:people count each.satisfied;
			}
		}
	}
}