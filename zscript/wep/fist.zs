// ------------------------------------------------------------
// Fist
// ------------------------------------------------------------
class HDFistPuncher:IdleDummy{
	default{
		+bloodlessimpact +nodecal +hittracer +puffonactors
		stamina 1;
	}
}
class HDFist:HDWeapon replaces Fist{
	int targettimer;
	int targethealth;
	int targetspawnhealth;
	bool flicked;
	bool washolding;
	default{
		+WEAPON.MELEEWEAPON +WEAPON.NOALERT +WEAPON.NO_AUTO_SWITCH
		+forcepain
		obituary "%o made %k take the kid gloves off.";
		attacksound "*fist";
		weapon.selectionorder 100;
		weapon.kickback 120;
		weapon.bobstyle "Alpha";
		weapon.bobspeed 2.6;
		weapon.bobrangex 0.1;
		weapon.bobrangey 0.5;
		weapon.slotnumber 1;
		hdweapon.nicename "Fists";
		hdweapon.refid HDLD_FIST;
	}
	override void DrawHUDStuff(HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl){
		let ww=HDFist(hdw);
		if(ww.targethealth)sb.drawwepnum(ww.targethealth,ww.targetspawnhealth);
	}
	override string gethelptext(){
		return
		WEPHELP_FIRE.."  Punch\n"
		..WEPHELP_ALTFIRE.."   Lunge\n"
		..WEPHELP_RELOAD.."   Distracting strike\n"
		..WEPHELP_FIREMODE.."   Grab/Drag\n"
		..WEPHELP_UNLOAD.."   Distracting projectile\n"
		..WEPHELP_ZOOM.."+"..WEPHELP_DROP.."   Drop misc. items\n"
		;
	}
	override inventory CreateTossable(int amount){
		if(
			!owner
			||!owner.player
			||!(owner.player.cmd.buttons&BT_ZOOM)
		)return null;
		array<inventory> items;items.clear();
		for(inventory item=owner.inv;item!=null;item=!item?null:item.inv){
			if(
				inventory(item)
				&&item.binvbar
				&&item.species!="HealingItem"
			){
				items.push(item);
			}
		}
		if(!items.size()){
			if(!HDWoundFixer.DropMeds(owner,0))owner.A_DropInventory("SpareWeapons");
			return null;
		}
		double aang=owner.angle;
		double ch=items.size()?20.:0;
		owner.angle-=ch*(items.size()-1)*0.5;
		owner.player.cmd.buttons&=~BT_ZOOM;
		for(int i=0;i<items.size();i++){
			owner.a_dropinventory(items[i].getclassname(),items[i].amount);
			owner.angle+=ch;
		}
		owner.angle=aang;
		return null;
	}
	override void DoEffect(){
		super.DoEffect();
		if(targettimer<70)targettimer++;else{
			tracer=null;
			targettimer=0;
			targethealth=0;
		}
	}
	action void A_CheckGender(statelabel st,int layer=PSP_WEAPON){
		if(player){
			int gnd=player.getgender();
			if(!gnd)gnd=getspriteindex("PUNGA0");
			else if(gnd==1)gnd=getspriteindex("PUNFA0");
			else if(gnd==2)gnd=getspriteindex("PUNFA0");
			else gnd=getspriteindex("PUNCA0");
			player.findPSprite(layer).sprite=gnd;
		}
	}
	action void HDPunch(int dmg){
		flinetracedata punchline;
		bool punchy=linetrace(
			angle,48,pitch,
			TRF_NOSKY,
			offsetz:height-12,
			data:punchline
		);
		if(!punchy)return;

		//actual puff effect if the shot connects
		LineAttack(angle,48,pitch,punchline.hitline?(countinv("PowerStrength")?random(50,120):random(5,15)):0,"none",
			countinv("PowerStrength")?"BulletPuffMedium":"BulletPuffSmall",
			flags:LAF_NORANDOMPUFFZ|LAF_OVERRIDEZ,
			offsetz:height-12
		);

		if(!punchline.hitactor){
			HDF.Give(self,"WallChunkAmmo",1);
			return;
		}
		actor punchee=punchline.hitactor;


		//the Rite of the Once-Mortal (YOLO mode only)
		//hold Zoom+Use on a downed player while all non-incapacitated players are present
		//everyone's permanent damage is traded for a few points of agg
		if(
			hd_yolo
			&&player.cmd.buttons&BT_ZOOM
			&&player.cmd.buttons&BT_USE
			&&hdplayerpawn(punchee)
			&&(
				!deathmatch
				||punchee.isteammate(self)
			)
		){
			let hdpch=hdplayerpawn(punchee);
			bool dotherite=hdpch.maxhealth()<50;
			if(dotherite){
				for(int i=0;i<MAXPLAYERS;i++){
					if(
						!playeringame[i]
						||!players[i].mo
						||players[i].mo.health<1
					)continue;
					let hdp=hdplayerpawn(players[i].mo);
					if(
						hdp
						&&(hdp.incapacitated&&hdp.health>15)
						&&(
							hdp.distance3d(self)<256
							||!checksight(hdp)
						)
					){
						A_Log("You must gather your party before performing the Rite of the Once-Mortal.");
						dotherite=false;
					}
				}
			}
			if(dotherite){
				for(int i=0;i<MAXPLAYERS;i++){
					if(
						!playeringame[i]
						||!players[i].mo
						||players[i].mo.health<1
					)continue;
					let hdp=hdplayerpawn(players[i].mo);
					if(!hdp)continue;
					hdp.healthreset();
					hdp.damagemobj(null,null,hdp.health-1,"maxhpdrain");
					if(hdp==hdpch){
						hdp.aggravateddamage=10;
						hdp.stunned=1400;
					}else{
						hdp.aggravateddamage=min(hdp.aggravateddamage+3,12);
						hdp.stunned=1000;
					}
				}
				A_Log("The Rite of the Once-Mortal is complete.");
				return;
			}
		}



		//charge!
		if(invoker.flicked)dmg*=1.5;
		else dmg+=HDMath.TowardsEachOther(self,punchee)*2;

		//come in swinging
		let onr=hdplayerpawn(self);
		if(onr){
			int iy=max(abs(player.cmd.pitch),abs(player.cmd.yaw));
			if(iy>0)iy*=100;
			else if(iy<0)iy*=200;
			dmg+=min(abs(iy),dmg*2);

			//need to be well grounded
			if(floorz<pos.z)dmg*=0.5;
		}

		//shit happens
		dmg*=frandom(0.6,1.6);


		//other effects
		if(
			onr
			&&!punchee.bdontthrust
			&&(
				punchee.mass<200
				||(
					punchee.radius*2<punchee.height
					&& punchline.hitlocation.z>punchee.pos.z+punchee.height*0.6
				)
			)
		){
			double iyaw=player.cmd.yaw*(65535./360.);
			if(abs(iyaw)>(0.5)){
				punchee.A_SetAngle(punchee.angle-iyaw*100,SPF_INTERPOLATE);
			}
			double ipitch=player.cmd.pitch*(65535./360.);
			if(abs(ipitch)>(0.5*65535/360)){
				punchee.A_SetPitch(punchee.angle+ipitch*100,SPF_INTERPOLATE);
			}
		}
		//headshot lol
		if(
			!punchee.bnopain
			&& punchee.health>0
			&& !(punchee is "HDBarrel")
			&& punchee.findstate("pain")
			&& punchline.hitlocation.z>punchee.pos.z+punchee.height*0.75
		){
			if(hd_debug)A_Log("HEAD SHOT");
			punchee.setstatelabel("pain");
			dmg*=frandom(1.1,1.8);
		}

		if(hd_debug){
			string pch="";
			if(punchee.player)pch=punchee.player.getusername();
				else pch=punchee.getclassname();
			A_Log(string.format("Punched %s for %i damage!",pch,dmg));
		}
		if(dmg*2>punchee.health)punchee.A_PlaySound("misc/bulletflesh",CHAN_BODY);  
		punchee.damagemobj(self,self,dmg,"SmallArms0");

		if(!punchee)invoker.targethealth=0;else{
			invoker.targethealth=punchee.health;
			invoker.targetspawnhealth=punchee.spawnhealth();
			invoker.targettimer=0;
		}
	}
	action void A_Lunge(){
		hdplayerpawn hdp=hdplayerpawn(self);
		if(hdp){
			if(hdp.fatigue>=30){setweaponstate("hold");return;}
			else hdp.fatigue+=3;
		}
		double overloaded=hdp.CheckEncumbrance();
		A_Recoil(min(overloaded*0.6,4.)-4.);
		hdp.overloaded=overloaded;
	}
	static void kick(actor kicker,actor kickee,actor kicking){
		kickee.A_PlaySound("weapons/smack",CHAN_BODY);
		bool kzk=kicker.countinv("PowerStrength");
		kickee.damagemobj(kicking,kicker,kzk?random(20,40):random(10,20),"bashing");
		if(!kickee)return;
		if(
			kickee.findstate("pain")
			&&!kickee.bnopain
			&&kickee.health>0
			&&random(0,4)
		)kickee.setstatelabel("pain");
		vector3 kickdir=(kickee.pos-kicker.pos).unit();
		kickee.vel=kickdir*(kzk?10:2)*kicker.mass/max(kicker.mass*0.3,kickee.mass);
		kicker.vel-=kickdir;
	}

	actor grabbed;
	double grabangle;
	action void A_CheckGrabbing(){
		let grabbed=invoker.grabbed;
		let grabangle=invoker.grabangle;

		//if no grab target, find one
		if(!grabbed){
			flinetracedata glt;
			linetrace(
				angle,
				36,
				pitch,
				TRF_ALLACTORS,
				height-18,
				data:glt
			);
			if(!glt.hitactor){
				A_ClearGrabbing();
				return;
			}
			let grbd=glt.hitactor;
			grabbed=grbd;
			grabangle=grbd.angle;
			invoker.grabangle=grabangle;
			invoker.grabbed=grbd;
		}
		bool resisting=(
			(
				grabbed.bismonster
				&&!grabbed.bnofear&&!grabbed.bghost //*ERPs use both of these flags
				&&grabbed.health>0
			)||(
				grabbed.player
				&&(
					!hdplayerpawn(grabbed)
					||!hdplayerpawn(grabbed).incapacitated
				)&&(
					grabbed.player.cmd.forwardmove
					||grabbed.player.cmd.sidemove
					||grabbed.player.cmd.pitch
					||grabbed.player.cmd.yaw
				)
			)
		);
		bool zerk=(
			hdplayerpawn(self)
			&&hdplayerpawn(self).zerk>100
		);
		//chance to break away
		if(resisting){
			vel+=(frandom(-1,1),frandom(-1,1),frandom(-1,1));
			let grabbedmass=grabbed.mass;
			if(random(grabbedmass*0.1,grabbedmass)>random(mass*0.6,mass*(zerk?5:1))){
				vector2 thrustforce=(cos(angle),sin(angle))*frandom(0.,2.);
				grabbed.vel.xy+=thrustforce*min(mass/grabbed.mass,1.);
				vel.xy-=thrustforce;
				A_ClearGrabbing();
				return;
			}
			if(absangle(angle,grabangle)>10)invoker.grabangle-=frandom(10,20);
			if(!random(0,7)){
				grabbed.damagemobj(self,self,1,"Melee");
				double newgrangle=(grabbed.angle+angle)*0.5;
				grabbed.angle=newgrangle;
				invoker.grabangle=newgrangle;
			}
		}
		double massfactor=max(1.,grabbed.mass*(1./200.));
		if(massfactor>7.){
			A_ClearGrabbing();
			return;
		}

		double grangle=grabbed.angle*2;
		grabbed.A_SetAngle((grabangle+grangle)*0.333333333333333,SPF_INTERPOLATE);

		//drag
		double mindist=grabbed.radius+radius;

		double dragfactor=min(0.8,0.8*mass/grabbed.mass);
		usercmd cmd=player.cmd;
		int fm=cmd.forwardmove>0?1:cmd.forwardmove<0?-1:0;
		int sm=cmd.sidemove>0?1:cmd.sidemove<0?-1:0;
		if(!sm&&fm<0)dragfactor*=1.7;

		vector2 dragmove=rotatevector((dragfactor*fm,-dragfactor*sm),angle)*player.crouchfactor;
		if(trymove(pos.xy+dragmove,true)){
			let p=HDPlayerPawn(self);
			if(p)p.movehijacked=true;
		}

		let gdst=grabbed.maxstepheight;
		let gddo=grabbed.bnodropoff;
		grabbed.maxstepheight=maxstepheight;
		grabbed.bnodropoff=false;
		grabbed.trymove(grabbed.pos.xy+dragmove,true);
		grabbed.maxstepheight=gdst;
		grabbed.bnodropoff=gddo;
		grabbed.setz(max(grabbed.pos.z,grabbed.floorz));

		string grbng="dragging ";
		if(grabbed.bcorpse)grbng=grbng.."corpse";
		else if(inventory(grabbed)||hdupk(grabbed))grbng=grbng.."item";
		else grbng=grbng.."object";
		if(hd_debug)grbng=grbng.."\n"..grabbed.getclassname();
		A_WeaponMessage(grbng.."...",3);

		if(
			absangle(angle,angleto(grabbed))>60.
			||distance3d(grabbed)>(mindist+16)
		){
			A_ClearGrabbing();
			return;
		}
		invoker.grabangle=angle;
	}
	action void A_ClearGrabbing(){
		let p=HDPlayerPawn(self);if(p)p.movehijacked=false;
		invoker.grabbed=null;
		A_WeaponMessage("");
	}
	states{
	preload:
		PUNF ABCD 0;
		PUNG ABCD 0;
		PUNC ABCD 0;
		goto nope;
	ready:
		TNT1 A 1{
			if(invoker.washolding&&pressingfire()){
				setweaponstate("nope");
				return;
			}
			A_WeaponReady(WRF_ALL);
			invoker.flicked=false;
			invoker.washolding=false;
		}goto readyend;
	reload:
		TNT1 A 0 A_CheckGender("flick");
	flick:
		#### A 1 offset(0,50) A_Lunge();
		#### A 1 offset(0,36);
		#### A 0 A_JumpIfInventory("PowerStrength",1,"ZerkFlick");
		#### AAAAAAA 0 A_CustomPunch((1),1,CPF_PULLIN,"HDFistPuncher",36);
		goto flickend;
	zerkflick:
		#### AAAAAAA 0 A_CustomPunch((random(1,3)),1,CPF_PULLIN,"HDFistPuncher",36);
	flickend:
		#### AA 1 offset(0,38){invoker.flicked=true;}
		#### A 1 offset(0,42);
		#### A 1 offset(0,50);
		goto fire;
	fire:
	hold:
	althold:
		TNT1 A 0 A_CheckGender("startfire");
	startfire:
		#### A 0 A_JumpIfInventory("PowerStrength",1,"zerkpunch");
		goto punch;
	punch:
		#### B 1 offset(0,32);
		#### D 0 HDPunch(12);
		#### D 6;
		#### CB 3;
		TNT1 A 3;
		TNT1 A 0 A_JumpIf(pressingaltfire(),"altfire");
		TNT1 A 1 A_ReFire();
		goto ready;
	zerkpunch:
		#### D 0 A_Recoil(-1);
		#### D 0 HDPunch(invoker.flicked?140:100);
		#### D 3;
		#### CB 1;
		TNT1 A 5;
		TNT1 A 0 A_JumpIf(pressingaltfire(),"altfire");
		TNT1 A 2 A_ReFire();
		goto ready;
	altfire:
		#### A 1 offset(0,36);
		#### A 1 offset(0,50);
		TNT1 A 2 A_CheckFloor("lunge");
		goto kick;
	lunge:
		TNT1 A 0 A_Lunge();
		TNT1 AA 1{
			if(countinv("PowerStrength"))A_Recoil(-random(12,24));
		}
		TNT1 A 1 A_Recoil(-4);
	kick:
		TNT1 A 13{
			if(hdplayerpawn(self))hdplayerpawn(self).fatigue+=2;
			flinetracedata ktl;
			LineTrace(angle,radius*1.6,0,offsetz:10,data:ktl);
			if(ktl.hitactor)invoker.kick(self,ktl.hitactor,invoker);
			if(countinv("PowerStrength"))A_SetTics(8);
		}
		PUNF A 0 A_Refire();
		goto ready;
	grabhold:
		TNT1 A 1 A_CheckGrabbing();
		TNT1 A 0 A_JumpIf(pressingfire(),"fire");
		TNT1 A 0 A_JumpIf(pressingfiremode(),"grabhold");
		goto nope;
	firemode:
	grab:
		TNT1 A 0 A_CheckGender("grab2");
	grab2:
		#### A 1 offset(0,52);
		#### A 1 offset(0,32);
		#### A 1 offset(0,40);
		#### A 1 offset(0,52);
		goto grabhold;
	spawn:
		TNT1 A 1;
		stop;
	}
}

