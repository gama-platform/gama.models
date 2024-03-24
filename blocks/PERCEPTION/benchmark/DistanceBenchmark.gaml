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
	
	float bench_dt;
	float bench_mdt;
	
	float bench_clsvrlpng;
	float bench_clsfwdt;
	float bench_clst;
	float bench_clsansd;
	float bench_aad;
	
	float bench_clsvrlpng_wc;
	float bench_clsfwdt_wc;
	float bench_clst_wc;
	float bench_clsansd_wc;
	float bench_clsaad_wc;
	
	int nbagent <- 100 parameter:true min:100 max:5000;
	bool dist <- true parameter:true;
	bool clos <- true parameter:true;
	bool clos_condition <- true parameter:true;
	
	init {
		
		create a number:nbagent;
		
	}
	
	reflex distance_to_bench {
		
		loop times:100 {
			point p1 <- any_location_in(shape);
			point p2 <- any_location_in(shape);
			
			float t <- machine_time;
			float dt <- p1 distance_to p2;
			bench_dt <- bench_dt + machine_time - t;
			
			t <- machine_time;
			float mdt <- sqrt((p1 - p2).x^2 + (p1 - p2).y^2);
			bench_mdt <- bench_mdt + machine_time - t;
			
			if dt!=mdt {error "Calculus error : "+sample(dt)+" | "+sample(mdt);}
		}
		
	}
	
}

species a skills:[moving] {
	
	reflex dowander { do wander amplitude:90; }
	
	reflex bench_distance when:dist{
		float t <- machine_time;
		list<a> nsd <- a inside (self buffer 2#m);
		bench_inside <- bench_inside + machine_time - t;
		
		t <- machine_time;
		list<a> vrlp <- a overlapping (self buffer 2#m);
		bench_ovlpping <- bench_ovlpping + machine_time - t;
		
		t <- machine_time;
		list<a> vrl <- a where (each overlaps (self buffer 2#m));
		bench_overlaps <- bench_overlaps + machine_time - t; 
		
		t <- machine_time;
		list<a> dist <- a where (each distance_to self < 2#m);
		bench_distanceto <- bench_distanceto + machine_time - t;
		
		t <- machine_time;
		list<a> dist <- a at_distance 2#m;
		bench_atdistance <- bench_atdistance + machine_time - t;
	}
	
	reflex closest_distance when:clos{
		float t <- machine_time;
		a vrlp <- any(a overlapping (self buffer 2#m));
		bench_clsvrlpng <- bench_clsvrlpng + machine_time - t;
		
		t <- machine_time;
		a clsfw <- a first_with (each distance_to self < 2#m);
		bench_clsfwdt <- bench_clsfwdt + machine_time - t; 
		
		t <- machine_time;
		a clst <- a closest_to self;
		clst <- clst distance_to self < 2#m ? clst : nil; 
		bench_clst <- bench_clst + machine_time - t; 
		
		t <- machine_time;
		a clansd <- agents_inside(self buffer 2#m) first_with (each is a);
		bench_clsansd <- bench_clsansd + machine_time - t;
		
		t <- machine_time;
		a aad <- any(a at_distance 2#m);
		bench_aad <- bench_clsansd + machine_time - t;
		
	}
	
	reflex closest_with_condition when:clos_condition{
		
		list<a> agent_sublist <- int(nbagent*0.5) among a;
		
		float t <- machine_time;
		a vrlp <- any(agent_sublist overlapping (self buffer 2#m));
		bench_clsvrlpng_wc <- bench_clsvrlpng_wc + machine_time - t;
		
		t <- machine_time;
		a clsfw <- agent_sublist first_with (each distance_to self < 2#m);
		bench_clsfwdt_wc <- bench_clsfwdt_wc + machine_time - t; 
		
		t <- machine_time;
		a clst <- agent_sublist closest_to self;
		clst <- clst distance_to self < 2#m ? clst : nil; 
		bench_clst_wc <- bench_clst_wc + machine_time - t; 
		
		t <- machine_time;
		a clansd <- agents_inside(self buffer 2#m) first_with (agent_sublist contains each);
		bench_clsansd_wc <- bench_clsansd_wc + machine_time - t;
		
		t <- machine_time;
		a claad <- any(agent_sublist at_distance 2#m);
		bench_clsaad_wc <- bench_clsaad_wc + machine_time - t;
	}
}

experiment xp {
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
			chart "collect people around (sec)" type:series visible:dist
				position:{0,0} size:clos?{0.5,0.5}:(clos_condition?{0.5,1}:{1,1}) {
				data "a inside (self buffer 2#m)" value:bench_inside/1000;
				data "a overlapping (self buffer 2#m)" value:bench_ovlpping/1000;
				data "a where (each overlaps (self buffer 2#m))" value:bench_overlaps/1000;
				data "a where (each distance_to self < 2#m)" value:bench_distanceto/1000;
				data "a at_distance 2#m)" value:bench_atdistance/1000;
			}
		
			chart "closest agent in range" type:series visible:clos
				position:dist?{0,0.5}:{0,0} size:dist?{0.5,0.5}:(clos_condition?{0.5,1}:{1,1}) {
				data "any(a overlapping (self buffer 2#m))" value:bench_clsvrlpng/1000;
				data "a first_with (each distance_to self < 2#m)" value:bench_clsfwdt/1000;
				data "a clst <- a closest_to self; clst <- clst distance_to self < 2#m ? clst : nil;" value:bench_clst/1000;
				data "agents_inside(self buffer 2#m) first_with (each is a)" value:bench_clsansd/1000;
				data "any(a at_distance 2#m)" value:bench_aad/1000;
				
			}
			chart "closest agent in range with conditions" type:series visible:clos_condition 
				position:dist?{0.5,0.0}:(clos?{0.5,0.0}:{0,0}) size:dist?{0.5,0.5}:(clos?{0.5,1}:{1,1}) {
				data "any(agent_sublist overlapping (self buffer 2#m))" value:bench_clsvrlpng_wc/1000;
				data "agent_sublist first_with (each distance_to self < 2#m)" value:bench_clsfwdt_wc/1000;
				data "a clst <- agent_sublist closest_to self; clst <- clst distance_to self < 2#m ? clst : nil;" value:bench_clst_wc/1000;
				data "agents_inside(self buffer 2#m) first_with (agent_sublist contains each)" value:bench_clsansd_wc/1000;
				data "any(agent_sublist at_distance 2#m)" value:bench_clsansd_wc/1000;
			}
		}
	}
}