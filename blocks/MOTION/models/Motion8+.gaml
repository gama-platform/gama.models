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
			// Create the other way round road
			create r {
				num_lanes <- 2;
				shape <- line(reverse(myself.shape.points));
				linked_road <- myself;
				myself.linked_road <- self;
			}
		}
		
		// Create intersections
		create i from:g.vertices;
		
		g <- as_driving_graph(r,i);
		
		// Turn some intersections into trafic lights
		ask i where (length(each.roads_in) > 2) {
			orientations <- [{0,-2},{2,0},{0,2},{-2,0}];
			if flip(0.4) {
				seq <- 45#s;
				stop << []; // ???
				ways <- [[],[]];
				loop rd over:roads_in {
					list<point> pts2 <- r(rd).shape.points;
					float angle_dest <- last(pts2) direction_to rd.location;
					if angle_dest=90 or angle_dest=270 {ways[0] <+ rd;} else {ways[1] <+ rd;}
				}
			}
		}
		
		create a number:10 {location <- any_location_in(any(g.edges)); color <- rnd_color(255);}
	}
	
}

species a skills:[driving] {
	
	rgb color;
	
	reflex move { 
		do drive_random graph:g;
	}
	
	aspect default {
		draw rectangle(1,3) rotate:heading+90 color:color;
	}
	
}

species r skills:[road_skill] {
	aspect default { draw shape color: #black end_arrow: 1; }
}

species i skills:[intersection_skill] {
	
	list<point> orientations;
	
	list<list<r>> ways;
	
	float seq <- #infinity;
	bool green <- true;
	
	reflex lights when:every(seq) and not(empty(ways)){
		green <- green ? false : true;
		stop[0] <- ways[green?0:1];
	}
	
	aspect default { 
		loop xy over:orientations {
			draw rectangle({1+abs(xy.y),1+abs(xy.x)}) at:location+xy 
				color:empty(ways)?#grey : (abs(xy.x)=(green?0:2)?#red:#green);
		}
	}
}

experiment xp {
	float minimum_cycle_duration <- 0.02;
	output {
		display main type:3d {
			species i;
			species r;
			species a;
		}
	}
	
}