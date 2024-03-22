/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Move

/* Insert your model definition here */

global {
	
	float step <- 0.2#s;
	
	graph g;
	
	int speedlimit <- 50 min:20 max:110 parameter:true;
	
	init {
		
		float wx <- world.shape.width;
		float wy <- world.shape.height;
		list<geometry> lines;
		loop l from:1 to:3 { 
			lines <+ line({0,wx/4*l},{wy,wx/4*l});
			lines <+ line({wy/4*l,0},{wy/4*l,wx});
		}
		
		g <- as_edge_graph(clean_network(lines,0.5,true,false));
		
		// Each line of the graph is a road
		create r from:g.edges {
			num_lanes <- 2;
			maxspeed <- rnd(speedlimit);
			// Create the other way round road
			create r {
				num_lanes <- 2;
				shape <- line(reverse(myself.shape.points));
				maxspeed <- myself.maxspeed;
				linked_road <- myself;
				myself.linked_road <- self;
			}
		}
		
		create i from:g.vertices;
		
		g <- as_driving_graph(r,i);
		
		create a number:10 {location <- any_location_in(any(g.edges)); color <- rnd_color(255);}
	}
	
}

species a skills:[driving] {
	
	geometry shape <- circle(2);
	
	rgb color;
	
	reflex move { 
		do drive_random graph:g;
	}
	
	aspect default {
		draw shape color:color;
		loop s over:current_path {draw geometry(s) buffer 3 color:blend(color,#transparent,0.5);}
		draw pyramid(1) at:final_target color:color;
	}
	
}

species r skills:[road_skill] {
	aspect default { draw shape color: #black end_arrow: 1; }
}

species i skills:[intersection_skill] {
	aspect default { draw circle(2);}
}

experiment xp {
	output {
		display main type:3d {
			species i;
			species r;
			species a;
		}
	}
	
}