/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Move

/* Insert your model definition here */

global {
	
	float SPEED <- 0.2 parameter:true min:0.1 max:20;
	graph g;
	
	init {
		
		float wx <- world.shape.width;
		float wy <- world.shape.height;
		list<geometry> lines;
		loop l from:1 to:3 { 
			lines <+ line({0,wx/4*l},{wy,wx/4*l});
			lines <+ line({wy/4*l,0},{wy/4*l,wx});
		}
		g <- as_edge_graph(clean_network(lines,0.5,true,false));
		
		create a number:10 {location <- any_location_in(any(g.edges)); color <- rnd_color(255);}
	}
	
}

species a skills:[moving] {
	
	point dest <- any(g.vertices);
	geometry shape <- circle(2);
	
	rgb color;
	
	reflex move {		
		do goto target:dest on:g speed:SPEED;
						
		if location distance_to dest < 1#m { dest <- any(g.vertices); }
	}
	
	aspect default {
		draw shape color:color;
		loop s over:current_path {draw geometry(s) buffer 3 color:blend(color,#transparent,0.5);}
		draw pyramid(1) at:dest color:color;
	}
	
}


experiment xp {
	output {
		display main type:3d {
			graphics r { loop s over:g.edges {draw geometry(s) color:#black;} }
			species a;
		}
	}
	
}