// ------------------------------------------------------------
// Nice movement your objects have there.
// Shame if something happened to them.
// ------------------------------------------------------------


//All monsters should inherit from this.
class HDMobBase : HDActor{
	double bulletresistance;
	property bulletresistance:bulletresistance;
	default{
		monster;
		radius 12;
		hdmobbase.bulletresistance 1.;
	}
}



//general corpse-gibbing
class SawGib:InventoryFlag{
	default{
		inventory.maxamount int.MAX;
	}
	override void attachtoowner(actor user){
		super.attachtoowner(user);
		actor o=owner;
		if(owner){
			stamina=max(o.gibhealth,o.spawnhealth());
		}else destroy();
	}
	override void doeffect(){
		if(amount>stamina){
			actor o=owner;
			if(o)o.bdontgib=false;
			if(bmissileevenmore)return;
			bmissileevenmore=true;
			if(
				!o.bcorpse
				||!o.bshootable
				||o.health>0
			)destroy();
			else{
				o.bshootable=false;
				//use the old death state first
				if(o.findstate("XDeathBrewtleLulz"))o.setstatelabel("XDeathBrewtleLulz");
				else if(o.findstate("XXDeath"))o.setstatelabel("XXDeath");
				else o.bshootable=true;
				if(!o.bshootable)amount=0;
			}
		}
	}
}


class TauntHandler:EventHandler{
	override void NetworkProcess(ConsoleEvent e){

		//check to ensure the acting player can taunt
		let ppp = playerpawn(players[e.player].mo);
		if(!ppp) return;

		if(
			e.name~=="taunt"
			&&ppp.health>0 //delete if you want corpses taunting the enemy
		){
			ppp.A_PlaySound("*taunt",CHAN_VOICE);
			ppp.A_TakeInventory("powerfrightener");
			ppp.A_AlertMonsters();
		}
	}
}

//generic bleeding
//maybe use this for players too in the future???
class HDWound:Thinker{
	static void Inflict(actor bleeder,int amount){
		if(
			!skill||hd_nobleed
			||!bleeder.bshootable
			||bleeder.bnoblood
			||bleeder.bnoblooddecals
			||bleeder.bnodamage
			||bleeder.bdormant
			||bleeder.health<1
			||bleeder.bloodtype=="ShieldNeverBlood"

			//sorry there's no simple way to do this in the actor
			||bleeder is "Boner"
			||bleeder is "Yokai"
			||bleeder is "Putto"
			||bleeder is "Condemned"
			||bleeder is "Jailer"
			||bleeder is "HDBarrel"
			||bleeder is "ExplosiveBarrel"
			||bleeder is "BloodyHellFire"
			||bleeder is "ArchFiend"
		)return;

		let wwnd=new("HDWound");
		wwnd.owner=bleeder;
		wwnd.ticker=0;

		int modamt=getdefaultbytype(bleeder.getclass()).health;
		if(modamt>100)wwnd.amount=amount*100/modamt;
		else wwnd.amount=amount;
	}
	int ticker;
	int amount;
	actor owner;
	override void tick(){
		if(!owner||owner.health<1){destroy();return;}
		if(owner.isfrozen())return;
		ticker++;
		if(ticker>3){
//owner.A_LogInt(amount);
			ticker=0;
			if(amount>random(0,100)){
				owner.damagemobj(owner,null,max(1,(amount>>3)),"bleedout",DMG_NO_PAIN);
				if(owner.health<1&&amount<random(10,60))owner.deathsound="";
				owner.A_SpawnItemEx(owner.bloodtype,
					frandom(-12,12),frandom(-12,12),
					flags:SXF_USEBLOODCOLOR|SXF_NOCHECKPOSITION
				);
			}else if(amount<random(-100,67))amount--;
			if(amount<1||owner.health<1)destroy();
		}
	}
}


//static mob functions
struct HDMobAI play{
	//randomize size
	static void resize(actor caller,double minscl=0.9,double maxscl=1.,int minhealth=0){
		double scl=frandom(minscl,maxscl);
		double drad=caller.radius;double dheight=caller.height;
		double minchkscl=max(1.,minscl+0.1);
		while(
			//keep it smaller than the geometry
			scl>minchkscl&&  
			!caller.checkmove(caller.pos.xy,PCM_NOACTORS)
		){
			scl=frandom(minscl,maxscl);
			caller.A_SetSize(drad*scl,dheight*scl);
			maxscl=scl; //if this has to check again, don't go so high next time
		}
		caller.health*=max(scl,1);
		caller.scale*=scl;
		caller.mass*=scl;
		caller.speed*=scl;
		caller.meleerange*=scl;
	}

	//set and unset shootable corpse
	//in raise states, set gibbed to true to enable going to a raise-from-gib state
	static void CorpseFlags(actor caller,bool gibbed=false,bool raise=false){
		caller.A_TakeInventory("SawGib");
		caller.bdontgib=true;
		if(raise||caller.health>0){
			if(!caller.bfloat)caller.bnodropoff=true;
			caller.maxstepheight=getdefaultbytype(caller.getclass()).maxstepheight;
			caller.bnotautoaimed=false;
			caller.balwaystelefrag=false;
			caller.deathsound=getdefaultbytype(caller.getclass()).deathsound;
			if(gibbed&&caller.findinventory("IsGibbed")){
				caller.setstatelabel("raisegibbed");
				caller.A_TakeInventory("IsGibbed");
			}
			caller.bshootable=true;
			let aff=new("AngelFire");
			aff.master=caller;aff.ticker=0;

		}else{
			caller.A_NoBlocking();
			caller.bnodropoff=false;
			caller.maxstepheight=caller.height*0.1;
			caller.bnotautoaimed=true;
			caller.balwaystelefrag=true;
			if(gibbed)caller.A_GiveInventory("IsGibbed");
			else caller.bshootable=true;
		}
	}

	//taking all the same flags as A_LookEx
	static void Look(
		actor caller,
		int flags=0,
		double minseedist=0,
		double maxseedist=0,
		double maxheardist=0,
		double fov=0,
		statelabel label="see",
		int soundchance=127
	){
		caller.A_LookEx(flags,minseedist,maxseedist,maxheardist,fov,label);
		if(!caller.bambush)caller.angle+=random(-10,10);
		if(!random(0,soundchance))caller.A_PlaySound(caller.activesound);
	}

	//check if shot is clear
	//hdmobai.tryshoot(self,pradius:6,pheight:6)
	static bool TryShootAcceptableVictim(
		actor caller,
		actor victim,
		actor target,
		double error
	){
		return(
			victim==target
			||(
				victim&&
				(
					!victim.bshootable
					||(
						!(caller.isfriend(victim))
						&&!victim.bnodamage
					)
				)&&(
					caller.absangle(caller.angleto(victim),
						caller.angleto(target)
					)>error
				)
			)
		);
	}
	static bool TryShoot(
		actor caller,
		double shootheight=-1,
		double range=256,
		double pradius=0,
		double pheight=0,
		double error=1,
		actor target=null
	){
		if(!target)target=caller.target;
		if(!target)return false;
		if(shootheight<0)shootheight=caller.height-6;

		flinetracedata flt;

		//bottom centre - always done
		caller.linetrace(
			caller.angle,range,caller.pitch,flags:0,
			offsetz:shootheight,
			offsetside:0,
			data:flt
		);
		if(
			flt.hittype!=Trace_HitNone
			&&!TryShootAcceptableVictim(caller,flt.hitactor,target,error)
		)return false;

		//get zoffset for top shot
		shootheight+=pheight;

		//top centre
		if(pheight){
			caller.linetrace(
				caller.angle,range,caller.pitch,flags:0,
				offsetz:shootheight,
				offsetside:0,
				data:flt
			);
			if(
				flt.hittype!=Trace_HitNone
				&&!TryShootAcceptableVictim(caller,flt.hitactor,target,error)
			)return false;
		}

		//get zoffset for side shots
		if(!pradius)return true;
		shootheight-=pheight*0.5;

		//left and right
		caller.linetrace(
			caller.angle,range,caller.pitch,flags:0,
			offsetz:shootheight,
			offsetside:-pradius,
			data:flt
		);
		if(
			flt.hittype!=Trace_HitNone
			&&!TryShootAcceptableVictim(caller,flt.hitactor,target,error)
		)return false;
		caller.linetrace(
			caller.angle,range,caller.pitch,flags:0,
			offsetz:shootheight,
			offsetside:pradius,
			data:flt
		);
		if(
			flt.hittype!=Trace_HitNone
			&&!TryShootAcceptableVictim(caller,flt.hitactor,target,error)
		)return false;

		//if none of the checks fail
		return true;
	}

	//set a feartarget for nearby mobs
	//hdmobai.frighten(self,256); maybe 128 for bullet and 512 for plasma and bfg
	static void Frighten(actor caller,double fraidius,actor fearsome=null){
		if(!fearsome)fearsome=caller;
		fearsome.A_AlertMonsters();
		actor hir;
		blockthingsiterator it=blockthingsiterator.create(caller,fraidius);
		while(it.Next()){
			hir=it.thing;
			if(hir
				&& hir.bIsMonster
				&& hir.health>0
				&& hir.goal is "HDMobster"
			){
				HDMobster(hir.goal).threat=fearsome;
				HDMobster(hir.goal).thraidius=fraidius;
			}
		}
	}

	//smooth wander
	//basically smooth chase with less crap to deal with
	static void Wander(
		actor caller,
		bool dontlook=false
	){
		if(!caller.checkmove(caller.pos.xy)){
			caller.A_Wander();
			return;
		}

		//remember original position, etc.
		vector3 pg=caller.pos;

		double speedbak=caller.speed;
		bool benoteleport=caller.bnoteleport;
		caller.bnoteleport=true;
		if(!caller.target||caller.target.health<1)caller.speed*=0.5;

		//wander and record the resulting position
		caller.A_Wander();
		vector3 pp=caller.pos;

		if(!caller.bfloat && caller.floorz<caller.pos.z)return; //abort if can't propel caller
		caller.vel.xy*=0.7; //slow down

		//reset position and move in chase direction
		if(pp!=pg){
			if(!caller.bteleport)caller.setorigin(pg,false);
			if(caller.bfloat){
				caller.vel.xy+=caller.angletovector(caller.angle,caller.speed*0.16);
			}else{
				caller.vel.xy+=caller.angletovector(caller.angle,caller.speed*0.16);
			}
		}

		//look
		if(!dontlook)caller.A_Look();

		//reset things
		caller.bnoteleport=benoteleport;
		caller.speed=getdefaultbytype(caller.getclass()).speed;
	}
	//smooth chase
	//do NOT try to set targets in here, JUST do the chase sequence
	enum hdchaseflags{
		CHF_TURNLEFT=8,
		CHF_INITIALIZED=16,
		CHF_FLOATDOWN=32,
	}
	static void chase(actor caller,
		statelabel meleestate="melee",
		statelabel missilestate="missile",
		int flags=0,
		bool flee=false
	){
		double oldang=caller.angle;
		if(!caller.target){
			caller.A_ClearTarget();
			if(caller.curstate==caller.resolvestate("see")){
				if(caller.findstate("idle"))caller.setstatelabel("idle");
				else caller.setstatelabel("spawn");
			}
			return;
		}else if(!caller.checkmove(caller.pos.xy)){
			caller.A_Wander();
			return;
		}else{
			bool befrightened=caller.bfrightened;
			bool bechasegoal=caller.bchasegoal;
			bool benoteleport=caller.bnoteleport;
			int bminmissilechance=caller.minmissilechance;
			vector3 oldpos=caller.pos;

			caller.minmissilechance<<=1;
			caller.bnoteleport=true;
			if(flee){
				caller.bfrightened=true;
				caller.bchasegoal=false;
			}

			caller.A_Chase(meleestate,missilestate,flags);

			vector3 posdif=caller.pos-oldpos;
			caller.setorigin(oldpos,false);
			if(caller.bfloat&&caller.bnogravity)caller.vel*=0.7;
			else caller.vel.xy*=0.7;
			if(posdif!=(0,0,0))caller.vel+=posdif.unit()*caller.speed*0.16;

			caller.bfrightened=befrightened;
			caller.bchasegoal=bechasegoal;
			caller.bnoteleport=benoteleport;
			caller.minmissilechance=bminmissilechance;
		}
	}

	//eyeball out how much one's projectile will drop and raise pitch accordingly
	static void DropAdjust(actor caller,
		class<actor> missiletype,
		double dist=0,
		double speedmult=1.,
		double gravity=0,
		actor target=null
	){
		if(!target)target=caller.target;
		if(!target)return;
		if(dist<1)dist=max(1,(target?caller.distance2d(target):1));
		if(!gravity)gravity=getdefaultbytype(missiletype).gravity;
		double spd=getdefaultbytype(missiletype).speed*speedmult;
		if(getdefaultbytype(missiletype).gravity&&dist>spd){    
			int ticstotake=dist/spd;
			int dropamt=0;
			for(int i=1;i<=ticstotake;i++){
				dropamt+=i;
			}
			caller.pitch-=min(atan(dropamt*gravity/dist),30);
		}

		//because we don't shoot from height 32 but 42
		if(dist>0)caller.pitch+=atan(10/dist);
	}
}
class TryShootPuff:CheckPuff{
	default{
		-alwayspuff
	}
}

//not just an old web 1.0 host anymore
class AngelFire:Thinker{
	actor master;
	int ticker;
	override void Tick(){
		ticker++;
		if(!ticker||(ticker%7))return;
		if(
			!master
			||!master.bfriendly
			||master.health<1
		){
			destroy();
			return;
		}
		if(ticker>(35*60*15)){
			master.A_Die();
			destroy();
			return;
		}
		master.givebody(1);
		double mrad=master.radius*0.3;
		vector3 flamepos=master.pos+(
			frandom(-mrad,mrad),
			frandom(-mrad,mrad),
			frandom(0.4,0.6)*master.height
		);
		let fff=actor.spawn("HDFlameRed",flamepos,ALLOW_REPLACE);
		fff.vel=master.vel+(frandom(-0.3,0.3),frandom(-0.3,0.3),0.6);
	}
}



//actor that sets monster's goal
class HDMobster:IdleDummy{
	vector3 firstposition;
	actor threat;
	double thraidius;
	int leftright;
	int boredthreshold;int bored;
	actor healablecorpse;
	default{
		meleethreshold 0;
	}
	static hdmobster SpawnMobster(actor caller){
		let hdmb=hdmobster(spawn("HDMobster",caller.pos,ALLOW_REPLACE));
		hdmb.master=caller;
		hdmb.target=caller.target;
		hdmb.bfrightened=caller.bfrightened;
		hdmb.meleerange=caller.meleerange;
		return hdmb;
	}
	override void postbeginplay(){
		super.postbeginplay();
		firstposition=pos;
		leftright=randompick(-1,-1,-1,-1,0,1,1);
		threat=null;thraidius=256;
		bored=0;boredthreshold=20;
		healablecorpse=null;
		changetid(123); //only used for actoriterator
	}
	states{
	spawn:
		TNT1 A random(17,30){
			if(
				!master
				//abort if something else is setting the goal, e.g. a level script
				||(master.goal&&master.goal!=self)
			){
				destroy();return;
			}
			bfriendly=master.bfriendly;
			if(bfriendly)return;
			if(master.health<1){
				threat=null;
				return;
			}

			//see if this is a healer
			if(!random(0,14))healablecorpse=null;
			if(
				master.findstate("heal")
				&&!threat
			){
				blockthingsiterator it=blockthingsiterator.create(master,256);
				while(it.next()){
					actor itt=it.thing;
					if(
						itt.bcorpse
						&&itt.canresurrect(self,true)
						&&canresurrect(itt,false)
//						&&itt.findstate("raise")
						&&!random(0,4)
						&&abs(itt.pos.z-master.pos.z)<master.maxstepheight*2
						&&heat.getamount(itt)<50
						&&itt.checksight(master)
					){
						healablecorpse=itt;
						if(
							itt.distance3d(master)<
							(itt.radius+master.radius+12)*HDCONST_SQRTTWO
						){
							itt.target=master.target;
							master.A_Face(itt);
							master.setstatelabel("heal");

							actor masbak=master.master;
							master.master=itt;
							master.A_RaiseMaster(
								RF_TRANSFERFRIENDLINESS
								|RF_NOCHECKPOSITION
							);
							master.master=masbak;
						}
						break;
					}
				}
			}

			//decide where to place goal
			target=master.target;
			if(threat){
				bored=0;
				master.bfrightened=true;
				master.goal=self;master.bchasegoal=true;
				setorigin(master.pos+(master.pos-threat.pos)
					+(random(-128,128),random(-128,128),0),false);
				A_SetTics(tics*4);
				if(
					!master.checksight(threat)
					||master.distance3d(threat)>thraidius  
				)threat=null;
			}else if(healablecorpse){
				master.bfrightened=bfrightened;
				master.goal=self;master.bchasegoal=true;
				setorigin(healablecorpse.pos,true);
			}else if(target){
				master.bfrightened=bfrightened;
				master.goal=self;master.bchasegoal=true;
				//chase target directly, or occasionaly randomize general direction
				if(
					target.health>0  
					&&master.checksight(target)
				){
					vector2 mpo=master.pos.xy;
					double mth=meleethreshold;
					vector2 tpo=master.target.pos.xy;
					if(
						(!mth||mth<distance3d(target))
						&&!random(0,7)
					){
						vector2 flank=rotatevector(mpo-tpo,
							random(30,80)*(leftright
								*randompick(1,1,1,1,-1,-1,0))
						);
						tpo+=flank;
					}
					setorigin((tpo,master.target.pos.z+master.target.height),false);
					bored=0;
				}else if(!random(0,15)){
					setorigin((
						master.pos.xy
						+rotatevector(pos.xy-master.pos.xy
							+(random(-512,512),random(-512,512)),
							random(60,120)*
							(leftright+randompick(1,1,1,1,-1,-1,0))
						)
					,master.pos.z),false);
					bored++;
				}
				if(bored>boredthreshold||(master.bfriendly&&!random(0,99))){
					bored=0;
					master.goal=null;master.bchasegoal=false;
					A_ClearTarget();master.A_ClearTarget();
					if(master.findstate("idle"))master.setstatelabel("idle");
					else master.setstatelabel("spawn");
				}
			}else{
				master.goal=null;master.bchasegoal=false;
				master.A_ClearTarget();
				setorigin(firstposition,false); //go back to start
			}
		}wait;
	}
}

