// ------------------------------------------------------------
// Brontornis Cannon
// ------------------------------------------------------------
class TerrorBolt:HDBullet{
	default{
		-noextremedeath
		height 2;radius 2;
		speed 500;mass 20000;accuracy 12;woundhealth 100;
		hdbullet.distantsounder "DoubleDistantShotgun";
		missiletype "HDGunsmoke";
		scale 0.08;translation "128:151=%[1,1,1]:[0.2,0.2,0.2]";
		seesound "weapons/riflecrack";
		obituary "%o played %k's cannon.";
	}
	override void postbeginplay(){
		super.postbeginplay();
		for(int i=2;i;i--){
			A_SpawnItemEx("TerrorSabotPiece",0,0,0,
				speed*cos(pitch)*0.01,(i==2?3:-3),speed*sin(pitch)*0.01,0,
				SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS
			);
		}
	}
	override void DieOnImpact(vector3 deathspot){
		if(throughthis&&throughthis==target)return;
		deathspot=blt.hitlocation-blt.hitdir*4;
		setorigin(deathspot,true);
		setstatelabel("death");
	}
	override void EmergeFromImpact(vector3 emergespot){
		dieonimpact(pos);
	}
	override actor Puff(int sp){
		dieonimpact(pos);
		return self;
	}
	states{
	spawn:
		MISL A -1;
	death:
		TNT1 A 16{
			A_SprayDecal("BrontoScorch",16);
			bmissile=false;
			vel*=0.01;
			if(tracer)tracer.damagemobj( //warhead damage
				self,target,
				random(12,24)*60,
				"SmallArms3",DMG_THRUSTLESS
			);
			doordestroyer.destroydoor(self,128,frandom(24,36),6);
			A_HDBlast(
				fragradius:256,fragdamage:256,fragdamagetype:"SmallArms1",
				immolateradius:64,immolateamount:random(4,20),immolatechance:32,
				gibradius:16,gibamount:random(4,20),
				source:target
			);
			if(tracer&&tracer.bcorpse)tracer.A_SetInventory("SawGib",tracer.countinv("SawGib")+100);
			DistantQuaker.Quake(self,3,35,256,12);

			if(max(abs(pos.x),abs(pos.y))>=32768)return;
			actor aaa=Spawn("WallChunker",pos,ALLOW_REPLACE);
			A_SpawnChunks("BigWallChunk",20,4,20);
			A_SpawnChunks("HDSmoke",4,1,7);
			aaa=spawn("HDExplosion",pos,ALLOW_REPLACE);aaa.vel.z=2;
			spawn("DistantRocket",pos,ALLOW_REPLACE);
			vel.z+=10;
			A_SpawnChunks("HDSmokeChunk",random(3,4),6,12);
		}stop;
	}
}
class TerrorSabotPiece:HDDebris{
	default{
		xscale 1;yscale 2.2;height 2;radius 2;
		translation "ice";
		bouncesound "misc/casing2";
	}
	states{
	spawn:
		TNT1 A 0 nodelay{
			int blh=random(20,35);
			A_ChangeVelocity(cos(pitch)*blh,frandom(-1,1),-sin(pitch)*blh,CVF_RELATIVE);
		}
	spawn2:
		RBRS A 2{angle+=45;}
		loop;
	death:
		---- A -1;
		stop;
	}
}
class TerrorCasing:HDDebris{
	default{
		scale 0.3;height 4;radius 4;bouncefactor 0.9;
		bouncesound "misc/casing4";
	}
	states{
	spawn:
		BSHX A 0 nodelay A_ChangeVelocity(cos(pitch),0,sin(-pitch)+3,CVF_RELATIVE);
	spawn2:
		BSHX ACBC random(1,3){angle+=45;}
		loop;
	death:
		---- A -1 A_ChangeVelocity(0,randompick(-1,1),0,CVF_RELATIVE);
		stop;
	}
}




class BrontornisRound:HDAmmo{
	default{
		+inventory.ignoreskill
		inventory.pickupmessage "Picked up a bolt.";
		hdpickup.nicename "Brontornis Shell";
		hdpickup.refid HDLD_BROBOLT;
		hdpickup.bulk ENC_BRONTOSHELL;
		scale 0.3;
	}
	override void GetItemsThatUseThis(){
		itemsthatusethis.push("Brontornis");
	}
	states{
	spawn:
		BROC A -1;
		stop;
	}
}


class Brontornis:HDWeapon{
	default{
		//$Category "Weapons/Hideous Destructor"
		//$Title "Brontornis"
		//$Sprite "BLSTA0"

		+hdweapon.fitsinbackpack
		weapon.selectionorder 60;
		weapon.slotnumber 7;
		weapon.kickback 100;
		weapon.bobrangex 0.21;
		weapon.bobrangey 0.86;
		scale 0.6;
		inventory.pickupmessage "You got the Brontornis!";
		obituary "%o was terrorized by %k's Brontornis cannon.";
		hdweapon.barrelsize 24,1,2;
		hdweapon.nicename "Brontornis Cannon";
		hdweapon.refid HDLD_BRONTO;
	}
	override bool AddSpareWeapon(actor newowner){return AddSpareWeaponRegular(newowner);}
	override hdweapon GetSpareWeapon(actor newowner,bool reverse,bool doselect){return GetSpareWeaponRegular(newowner,reverse,doselect);}
	override void tick(){
		super.tick();
		drainheat(BRONS_HEAT,12);
	}
	override double gunmass(){
		double amt=weaponstatus[BRONS_CHAMBER];
		return 6+amt*amt;
	}
	override double weaponbulk(){
		return 75+(weaponstatus[BRONS_CHAMBER]>1?ENC_BRONTOSHELLLOADED:0);
	}
	override string,double getpickupsprite(){return "BLSTA0",1.;}
	override void DrawHUDStuff(HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl){
		if(sb.hudlevel==1){
			sb.drawimage("BROCA0",(-48,-10),sb.DI_SCREEN_CENTER_BOTTOM,scale:(0.7,0.7));
			sb.drawnum(hpl.countinv("BrontornisRound"),-45,-8,sb.DI_SCREEN_CENTER_BOTTOM,font.CR_BLACK);
		}
		if(hdw.weaponstatus[BRONS_CHAMBER]>1)sb.drawwepdot(-16,-10,(5,3));
		sb.drawwepnum(
			hpl.countinv("BrontornisRound"),
			HDMath.MaxInv(hpl,"BrontornisRound")
		);
	}
	override string gethelptext(){
		return
		WEPHELP_FIRESHOOT
		..WEPHELP_ALTFIRE.." or "..WEPHELP_FIREMODE.."  Toggle zoom\n"
		..WEPHELP_RELOADRELOAD
		..WEPHELP_UNLOADUNLOAD
		;
	}
	override void DrawSightPicture(
		HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl,
		bool sightbob,vector2 bob,double fov,bool scopeview,actor hpc,string whichdot
	){
		int scaledyoffset=-4;
		if(scopeview&&hdw.weaponstatus[0]&BRONF_ZOOM){
			texman.setcameratotexture(hpc,"HDXHCAM5",2.6);
			sb.drawimage(
				"HDXHCAM5",(0,scaledyoffset)+bob,
				sb.DI_SCREEN_CENTER|sb.DI_ITEM_HCENTER|sb.DI_ITEM_TOP,
				scale:(0.42,0.42)
			);
			scaledyoffset=-6;
			sb.drawimage(
				"bstadia",(0,scaledyoffset)+bob,
				sb.DI_SCREEN_CENTER|sb.DI_ITEM_HCENTER|sb.DI_ITEM_TOP,
				scale:(1.2,1.2)
			);
		}else{
			double dotoff=max(abs(bob.x),abs(bob.y));
			if(dotoff<10){
				sb.drawimage(
					"riflsit4",(0,0)+bob*1.6,sb.DI_SCREEN_CENTER|sb.DI_ITEM_CENTER,
					alpha:0.8-dotoff*0.04,scale:(1.6,1.6)
				);
			}
			sb.drawimage(
				"xh25",(0,0)+bob,sb.DI_SCREEN_CENTER|sb.DI_ITEM_CENTER,
				scale:(1.6,1.6)
			);
		}
	}
	override void DropOneAmmo(int amt){
		if(owner){
			amt=clamp(amt,1,10);
			owner.A_DropInventory("BrontornisRound",1);
		}
	}
	states{
	select0:
		BLSG A 0;
		goto select0small;
	deselect0:
		BLSG A 0;
		goto deselect0small;
	ready:
		BLSG A 1 A_WeaponReady(WRF_ALL);
		goto readyend;
	altfire:
	firemode:
		BLSG A 1 offset(0,34);
		BLSG A 1 offset(0,36);
		BLSG A 2 offset(2,37){invoker.weaponstatus[0]^=BRONF_ZOOM;}
		BLSG A 1 offset(1,36);
		BLSG A 1 offset(0,34);
		goto nope;
	fire:
		BLSG A 1 offset(0,34){
			if(invoker.weaponstatus[BRONS_CHAMBER]<2){
				setweaponstate("nope");
				return;
			}
			A_GunFlash();
			A_PlaySound("weapons/bronto",CHAN_WEAPON);
			A_PlaySound("weapons/bronto",6);
			A_PlaySound("weapons/bronto2",7);
			actor tb;int grb;
			[grb,tb]=A_SpawnItemEx("TerrorBolt",
				0,0,height-6,vel.x,vel.y,vel.z,0,
				SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH
			);
			if(invoker.weaponstatus[0]&BRONF_ZOOM)tb.pitch-=2;
			invoker.weaponstatus[BRONS_CHAMBER]=1;
			invoker.weaponstatus[BRONS_HEAT]+=32;
		}
		BLSG B 2;
		goto nope;
	flash:
		BLSF A 1 bright{
			HDFlashAlpha(0,true);
			A_Light1();
		}
		TNT1 A 2{
			A_ZoomRecoil(0.5);
			A_Light0();
		}
		TNT1 A 0{
			int recoilside=randompick(-1,1);
			if(gunbraced()){
				A_GiveInventory("IsMoving",2);
				hdplayerpawn(self).gunbraced=false;
				A_ChangeVelocity(
					cos(pitch)*-frandom(0.8,1.4),0,
					sin(pitch)*frandom(0.8,1.4),
					CVF_RELATIVE
				);
				A_MuzzleClimb(
					recoilside*5,-frandom(3.,5.),
					recoilside*5,-frandom(3.,5.)
				);
			}else{
				A_ChangeVelocity(
					cos(pitch)*-frandom(1.8,3.2),0,
					sin(pitch)*frandom(1.8,3.2),
					CVF_RELATIVE
				);
				A_GiveInventory("IsMoving",7);
				A_MuzzleClimb(
					recoilside*5,-frandom(5.,13.),
					recoilside*5,-frandom(5.,13.)
				);
				A_MuzzleClimb(
					recoilside*5,-frandom(5.,13.),
					recoilside*5,-frandom(5.,13.),
					wepdot:true
				);
			}
			if(!binvulnerable
				&&(
					countinv("IsMoving")>6
					||floorz<pos.z
				)
			){
				givebody(max(0,11-health));
				damagemobj(invoker,self,10,"bashing");
				A_GiveInventory("IsMoving",5);
				A_ChangeVelocity(
					cos(pitch)*-frandom(2,4),0,sin(pitch)*frandom(2,4),
					CVF_RELATIVE
				);
			}
		}
		stop;
	reload:
		BLSG A 0{
			invoker.weaponstatus[0]&=~BRONF_JUSTUNLOAD;
			if(
				invoker.weaponstatus[BRONS_CHAMBER]>1
				||!countinv("BrontornisRound")
			)setweaponstate("nope");
		}goto unloadstart;
	unload:
		BLSG A 0{
			invoker.weaponstatus[0]|=BRONF_JUSTUNLOAD;
		}goto unloadstart;

	unloadstart:
		BLSG A 1;
		BLSG BBB 2 A_MuzzleClimb(
			-frandom(0.5,0.6),frandom(0.5,0.6),
			-frandom(0.5,0.6),frandom(0.5,0.6)
		);
		BLSG B 3 A_PlaySound("weapons/brontunload",CHAN_WEAPON);
		BLSG BBBBBBBB 0{invoker.drainheat(BRONS_HEAT,12);}
		BLSG B 12 offset(0,34){
			int chm=invoker.weaponstatus[BRONS_CHAMBER];
			invoker.weaponstatus[BRONS_CHAMBER]=0;
			if(chm<1){
				A_SetTics(6);
				return;
			}

			A_PlaySound("weapons/brontoload",CHAN_AUTO);
			if(chm>1){
				if(
					PressingUnload()
					&&!A_JumpIfInventory("BrontornisRound",0,"null")
				){
					A_SetTics(18);
					A_PlaySound("weapons/pocket");
					A_GiveInventory("BrontornisRound");
				}
				else A_SpawnItemEx("BrontornisRound",
					cos(pitch)*2,0,height-10-sin(pitch)*2,
					vel.x,vel.y,vel.z-frandom(-1,1),
					random(-3,3),SXF_ABSOLUTEMOMENTUM|
					SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH|
					SXF_TRANSFERTRANSLATION
				);
			}else if(chm==1){
				A_SpawnItemEx("TerrorCasing",
					cos(pitch)*4,0,height-10-sin(pitch)*4,
					vel.x,vel.y,vel.z-frandom(-1,1),
					frandom(-1,1),SXF_ABSOLUTEMOMENTUM|
					SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH|
					SXF_TRANSFERTRANSLATION
				);
			}
		}
		BLSG B 1 offset(0,36) A_JumpIf(invoker.weaponstatus[0]&BRONF_JUSTUNLOAD,"reloadend");
		BLSG B 1 offset(0,41) A_PlaySound("weapons/pocket",CHAN_WEAPON);
		BLSG B 1 offset(0,38);
		BLSG B 3 offset(0,36);
		BLSG B 3 offset(0,34);
		BLSG B 3 offset(0,35);
		BLSG B 4 offset(0,34){
			invoker.weaponstatus[BRONS_CHAMBER]=2;
			A_TakeInventory("BrontornisRound",1,TIF_NOTAKEINFINITE);
			A_PlaySound("weapons/brontoload",CHAN_WEAPON);
		}
		BLSG B 6 offset(0,33);
	reloadend:
		BLSG B 6 offset(0,34);
		BLSG B 2 offset(0,34) A_PlaySound("weapons/brontunload",CHAN_WEAPON);
		BLSG B 1 offset(0,36);
		BLSG B 1 offset(0,34);
		BLSG BA 4;
		BLSG A 0 A_PlaySound("weapons/brontoclose",CHAN_WEAPON);
		goto ready;

	spawn:
		BLST A -1;
		stop;
	}
	override void InitializeWepStats(bool idfa){
		weaponstatus[BRONS_CHAMBER]=2;
		if(!idfa){
			weaponstatus[0]=0;
			weaponstatus[BRONS_HEAT]=0;
		}
	}
	override void loadoutconfigure(string input){
		int zoom=getloadoutvar(input,"zoom",1);
		if(!zoom)weaponstatus[0]&=~BRONF_ZOOM;
		else if(zoom>0)weaponstatus[0]|=BRONF_ZOOM;
	}
}
enum brontostatus{
	BRONF_ZOOM=1,
	BRONF_JUSTUNLOAD=2,

	BRONS_STATUS=0,
	BRONS_CHAMBER=1,
	BRONS_HEAT=2,
};



//map pickup
class BrontornisSpawner:IdleDummy{
	states{
	spawn:
		TNT1 A 0 nodelay{
			A_SpawnItemEx("BrontornisRound",0,0,0,0,0,0,0,SXF_NOCHECKPOSITION);
			A_SpawnItemEx("BrontornisRound",3,0,0,0,0,0,0,SXF_NOCHECKPOSITION);
			A_SpawnItemEx("BrontornisRound",1,0,0,0,0,0,0,SXF_NOCHECKPOSITION);
			A_SpawnItemEx("BrontornisRound",-3,0,0,0,0,0,0,SXF_NOCHECKPOSITION);
			A_SpawnItemEx("Brontornis",0,0,0,0,0,0,0,SXF_NOCHECKPOSITION);
		}stop;
	}
}
