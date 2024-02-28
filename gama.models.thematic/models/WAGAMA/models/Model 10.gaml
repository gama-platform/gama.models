/**
* Name: model10
* Based on the internal skeleton template. 
* Author: Patrick Taillandier
* Tags: 
*/

model model10

global {
	shape_file nodes_shape_file <- shape_file("../includes/nodes_simple.shp");
	shape_file environment_shape_file <- shape_file("../includes/environment.shp");
	shape_file activities_shape_file <- shape_file("../includes/activities.shp");

	geometry shape <- envelope(environment_shape_file);
	
	int max_water_input <- 20;
	
	init {
		create intersection from: nodes_shape_file with: (id:read("ID"), id_next:read("ID_NEXT"));
		ask intersection {
			next_intersection <- intersection first_with (each.id = id_next);
		}
		create activity from: activities_shape_file {
			withdrawal_point <- intersection closest_to self;
			create owner {
				myself.my_owner <- self;
			}
		}
		create water; 
	}
}

species intersection {
	string id;
	string id_next;
	intersection next_intersection;
	water current_water;
	
	aspect default {
		draw square(1.0) color: #gray border: #black;
		
		if next_intersection != nil {
			draw line([self,next_intersection]) color: #black;
		}
	}
}

species activity {
	owner my_owner;
	intersection withdrawal_point;
	int min_water_input <- rnd(1,3);
	bool dysfunction <- false;
	
	reflex manage_water when:withdrawal_point.current_water != nil {
		water the_water <- withdrawal_point.current_water;
		if (the_water.quantity < min_water_input) {
			dysfunction <- true;
		} else {
			my_owner.money <- my_owner.money  + min_water_input ;
		}
		the_water.quantity <- the_water.quantity - min_water_input;
	} 
	
	aspect default {
		draw line([self,withdrawal_point]) color: #red;
		draw rectangle(4.0, 3.0) color: dysfunction ? #red : #green border: #black;
	}
}

species owner {
	int money;
}
species water {
	intersection current_intersection;
	int quantity <- rnd(max_water_input) min: 0;
	
	init {
		do move_to(first(intersection));
	}
	
	action move_to(intersection inter) {
		current_intersection <- inter;
		inter.current_water <- self;
		location <- current_intersection.location;
	}
	
	reflex flow {
		current_intersection.current_water <- nil;
		if (current_intersection.next_intersection != nil) {
			do move_to(current_intersection.next_intersection);
		}  else {
			create water ;
			ask activity {
				dysfunction <- false;
			}
			do die;
		}
	}
	aspect default {
		draw circle(quantity/5.0) color: #blue border: #black;
	}
}


experiment run_simulation type: gui {
	parameter "Max water input" var: max_water_input min: 0 max: 100;
	float minimum_cycle_duration <- 0.2;
	output {
		display map {
			species activity;
			species intersection;
			species water;
			
		}
		
		display chart {
			chart "water level" {
				data "water quantity" value: water sum_of (each.quantity) color: #blue;
			}
		}
		display owners {
			chart "owner money" {
				data "average owner money" value: owner mean_of each.money color: #gray;	
				data "min owner money" value: owner min_of each.money color: #red;
				data "max owner money" value: owner max_of each.money color: #green;
			}
		}
	}
}
