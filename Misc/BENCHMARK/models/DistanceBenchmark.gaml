/**
* Name: DistanceBenchmark
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model DistanceBenchmark

global {
	
	float bench_inside;
	float bench_ovlpping;
	float bench_overlaps;
	float bench_distanceto;
	float bench_atdistance;
	float bench_neighbors;
	
	float bench_dt;
	float bench_mdt;
	
	float bench_clsvrlpng;
	float bench_clsfwdt;
	float bench_clst;
	float bench_clsansd;
	float bench_aad;
	float bench_nat;
	
	float bench_clsvrlpng_wc;
	float bench_clsfwdt_wc;
	float bench_clst_wc;
	float bench_clsansd_wc;
	float bench_clsaad_wc;
	float bench_clsnat_wc;
	
	int nbagent <- 1000 ;
	bool dist <- true ;
	bool clos <- true ;
	bool clos_condition <- true;
	
	bool use_geometry_instead_of_points <- false;
	bool remove_slow_operators <- true;
	
	
	
	init {
		
		create a number:nbagent {
			if use_geometry_instead_of_points {
				shape <- circle(0.5);
			}
		}
		
	}
	
	reflex distance_to_bench {
		
		loop times:100 {
			point p1 <- any_location_in(shape);
			point p2 <- any_location_in(shape);
			
			float t <- gama.machine_time;
			float dt <- p1 distance_to p2;
			bench_dt <- bench_dt + gama.machine_time - t;
			
			t <- gama.machine_time;
			float mdt <- sqrt((p1 - p2).x^2 + (p1 - p2).y^2);
			bench_mdt <- bench_mdt + gama.machine_time - t;
			
			if dt!=mdt {error "Calculus error : "+sample(dt)+" | "+sample(mdt);}
		}
		
	}
	
}

species a skills:[moving] {
	
	reflex dowander { do wander amplitude:90.0; }
	
	reflex bench_distance when:dist{
		float t <- gama.machine_time;
		list<a> nsd <- a inside (self buffer 2#m);
		bench_inside <- bench_inside + gama.machine_time - t;
		
		t <- gama.machine_time;
		list<a> vrlp <- a overlapping (self buffer 2#m);
		bench_ovlpping <- bench_ovlpping + gama.machine_time - t;
		
		if not(remove_slow_operators) {
			t <- gama.machine_time;
			list<a> vrl <- a where (each overlaps (self buffer 2#m));
			bench_overlaps <- bench_overlaps + gama.machine_time - t; 
			
			t <- gama.machine_time;
			list<a> dist1 <- a where (each distance_to self < 2#m);
			bench_distanceto <- bench_distanceto + gama.machine_time - t;
		}
		t <- gama.machine_time;
		list<a> dist2 <- a at_distance 2#m;
		bench_atdistance <- bench_atdistance + gama.machine_time - t;
		
		t <- gama.machine_time;
		list<a> dist3 <- self neighbors_at 2#m;
		bench_neighbors <- bench_neighbors + gama.machine_time - t;
	}
	
	reflex closest_distance when:clos{
		float t <- gama.machine_time;
		a vrlp <- any(a overlapping (self buffer 2#m));
		bench_clsvrlpng <- bench_clsvrlpng + gama.machine_time - t;
		
		if not(remove_slow_operators) {
			t <- gama.machine_time;
			a clsfw <- a first_with (each distance_to self < 2#m);
			bench_clsfwdt <- bench_clsfwdt + gama.machine_time - t; 
		}
		
		t <- gama.machine_time;
		a clst <- a closest_to self;
		clst <- clst distance_to self < 2#m ? clst : nil; 
		bench_clst <- bench_clst + gama.machine_time - t; 
		
		t <- gama.machine_time;
		a clansd <- a(agents_inside(self buffer 2#m) first_with (each is a));
		bench_clsansd <- bench_clsansd + gama.machine_time - t;
		
		t <- gama.machine_time;
		a neigh <- any(self neighbors_at 2#m);
		bench_nat <- bench_nat + gama.machine_time - t;
		
		t <- gama.machine_time;
		a aad <- any(a at_distance 2#m);
		bench_aad <- bench_aad + gama.machine_time - t;
	
		
	}
	
	reflex closest_with_condition when:clos_condition{
		
		list<a> agent_sublist <- int(nbagent*0.5) among a;
		
		float t <- gama.machine_time;
		a vrlp <- any(agent_sublist overlapping (self buffer 2#m));
		bench_clsvrlpng_wc <- bench_clsvrlpng_wc + gama.machine_time - t;
		
		if not(remove_slow_operators) {
			t <- gama.machine_time;
			a clsfw <- agent_sublist first_with (each distance_to self < 2#m);
			bench_clsfwdt_wc <- bench_clsfwdt_wc + gama.machine_time - t; 
		}
		
		t <- gama.machine_time;
		a clst <- agent_sublist closest_to self;
		clst <- clst distance_to self < 2#m ? clst : nil; 
		bench_clst_wc <- bench_clst_wc + gama.machine_time - t; 
		
		t <- gama.machine_time;
		a clansd <- a(agents_inside(self buffer 2#m) first_with (agent_sublist contains each));
		bench_clsansd_wc <- bench_clsansd_wc + gama.machine_time - t;
		
		t <- gama.machine_time;
		a claad <- any(agent_sublist at_distance 2#m);
		bench_clsaad_wc <- bench_clsaad_wc + gama.machine_time - t;
		
		t <- gama.machine_time;
		a clanat <- self neighbors_at 2#m first_with (agent_sublist contains each);
		bench_clsnat_wc <- bench_clsnat_wc + gama.machine_time - t;
	}
}

experiment xp {
	parameter "number of agents" var: nbagent min:100 max:50000;
	parameter "Benchmark distance operators" var: dist ;
	parameter "Benchmark close operators" var: clos ;
	parameter "Benchmark close with condition operators" var: clos_condition;
	
	parameter "Use a circle(0.5) geometry for agent's shape instead of a point" var: use_geometry_instead_of_points;
	parameter "Remove too slow tests (which not use the quadtree) to accelerate the benchmark " var: remove_slow_operators;
	
	output {
		monitor FLT_inside value:with_precision(bench_inside/1000,2);
		monitor FLT_apping value:with_precision(bench_ovlpping/1000,2);
		monitor FLT_vrlaps value:with_precision(bench_overlaps/1000,2);
		monitor FLT_dstnc value:with_precision(bench_distanceto/1000,2);
		monitor FLT_atdst value:with_precision(bench_atdistance/1000,2);
		
		monitor CLS_anyvrlpng value:with_precision(bench_clsvrlpng/1000,2);
		monitor CLS_fwdt value:with_precision(bench_clsfwdt/1000,2);
		monitor CLS_clst value:with_precision(bench_clst/1000,2);
		monitor CLS_ansd value:with_precision(bench_clsansd/1000,2); 
		monitor CLS_aad value:with_precision(bench_aad/1000,2);
		
		monitor DT_dt value:bench_dt;
		monitor DT_mdt value:bench_mdt;
		
		display main type:2d {
			chart "collect people around (sec)" type:series visible:dist background: #lightgray
				position:{0,0} size:clos?{0.5,0.5}:(clos_condition?{0.5,1}:{1,1}) {
				data "a inside (self buffer 2#m)" value:bench_inside/1000;
				data "a overlapping (self buffer 2#m)" value:bench_ovlpping/1000;
				
				if not remove_slow_operators {
					data "a where (each overlaps (self buffer 2#m))" value:bench_overlaps/1000;
					data "a where (each distance_to self < 2#m)" value:bench_distanceto/1000;
				}
				data "a at_distance 2#m" value:bench_atdistance/1000;
				data "self neighbors_at 2#m" value:bench_neighbors/1000;
			}
		
			chart "closest agent in range" type:series background: #lightgray visible:clos
				position:dist?{0,0.5}:{0,0} size:dist?{0.5,0.5}:(clos_condition?{0.5,1}:{1,1}) {
				data "any(a overlapping (self buffer 2#m))" value:bench_clsvrlpng/1000;
				if not remove_slow_operators {
					data "a first_with (each distance_to self < 2#m)" value:bench_clsfwdt/1000;
				}
				data "a clst <- a closest_to self; clst <- clst distance_to self < 2#m ? clst : nil;" value:bench_clst/1000;
				data "agents_inside(self buffer 2#m) first_with (each is a)" value:bench_clsansd/1000;
				data "any(a at_distance 2#m)" value:bench_aad/1000;
				data "any(self neighbors_at 2#m)" value:bench_nat/1000;
				
			}
			chart "closest agent in range with conditions" background: #lightgray type:series visible:clos_condition 
				position:dist?{0.5,0.0}:(clos?{0.5,0.0}:{0,0}) size:dist?{0.5,0.5}:(clos?{0.5,1}:{1,1}) {
				data "any(agent_sublist overlapping (self buffer 2#m))" value:bench_clsvrlpng_wc/1000;
				if not remove_slow_operators {
					data "agent_sublist first_with (each distance_to self < 2#m)" value:bench_clsfwdt_wc/1000;
				}
				data "a clst <- agent_sublist closest_to self; clst <- clst distance_to self < 2#m ? clst : nil;" value:bench_clst_wc/1000;
				data "agents_inside(self buffer 2#m) first_with (agent_sublist contains each)" value:bench_clsansd_wc/1000;
				data "any(agent_sublist at_distance 2#m)" value:bench_clsansd_wc/1000;
				data "self neighbors_at 2#m first_with (agent_sublist contains each)" value:bench_clsnat_wc/1000;
			}
		}
	}
}