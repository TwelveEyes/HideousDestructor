// ------------------------------------------------------------
// A 12-gauge pump for protection
// ------------------------------------------------------------
class Hunter:HDShotgun{
	default{
		//$Category "Weapons/Hideous Destructor"
		//$Title "Hunter"
		//$Sprite "HUNTA0"

		weapon.selectionorder 31;
		weapon.slotnumber 3;
		weapon.bobrangex 0.21;
		weapon.bobrangey 0.86;
		scale 0.6;
		inventory.pickupmessage "You got the pump-action shotgun!";
		hdweapon.barrelsize 30,0.5,2;
		hdweapon.refid HDLD_HUNTER;
		hdweapon.nicename "Hunter";
	}
	int tubesize;
	override void postbeginplay(){
		super.postbeginplay();
		tubesize=((weaponstatus[0]&HUNTF_EXPORT)?5:7);
		if(weaponstatus[HUNTS_TUBE]>tubesize)weaponstatus[HUNTS_TUBE]=tubesize;
	}
	override string getobituary(actor victim,actor inflictor,name mod,bool playerattack){
		bool sausage=true;
		for(int i=0;i<MAXPLAYERS;i++){
			if(playeringame[i]&&(players[i].getgender()!=0)){
				sausage=false;
				break;
			}
		}
		if(
			sausage
			&&!(weaponstatus[HUNTS_FIREMODE]<1) //"pumped"
			&&inflictor is "HDBullet" //"brutally!" "full!" - not just bleeding!
		)return "%o was brutally pumped full of %k's hot, manly lead.";
		return obituary;
	}
	override string pickupmessage(){
		if(weaponstatus[0]&HUNTF_CANFULLAUTO)return string.format("%s You notice some tool marks near the fire selector...",super.pickupmessage());
		else if(weaponstatus[0]&HUNTF_EXPORT)return string.format("%s Where is the fire selector on this thing!?",super.pickupmessage());
		return super.pickupmessage();
	}
	override string,double getpickupsprite(){return "HUNT"..getpickupframe().."0",1.;}
	override void DrawHUDStuff(HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl){
		if(sb.hudlevel==1){
			sb.drawimage("SHL1A0",(-47,-10),basestatusbar.DI_SCREEN_CENTER_BOTTOM);
			sb.drawnum(hpl.countinv("HDShellAmmo"),-46,-8,
				basestatusbar.DI_SCREEN_CENTER_BOTTOM,font.CR_BLACK
			);
		}
		if(hdw.weaponstatus[HUNTS_CHAMBER]>1){
			sb.drawwepdot(-19,-11,(5,3));
			sb.drawwepdot(-16,-11,(2,3));
		}
		else if(hdw.weaponstatus[HUNTS_CHAMBER]>0){
			sb.drawwepdot(-16,-11,(2,3));
		}
		if(!(hdw.weaponstatus[0]&HUNTF_EXPORT))sb.drawwepcounter(hdw.weaponstatus[HUNTS_FIREMODE],
			-26,-12,"blank","RBRSA3A7","STFULAUT"
		);
		sb.drawwepnum(hdw.weaponstatus[HUNTS_TUBE],tubesize,posy:-7);
		for(int i=hdw.weaponstatus[SHOTS_SIDESADDLE];i>0;i--){
			sb.drawwepdot(-15-i*2,-2,(1,3));
		}
	}
	override string gethelptext(){
		return
		WEPHELP_FIRESHOOT
		..WEPHELP_ALTFIRE.."  Pump\n"
		..WEPHELP_RELOAD.."  Reload (side saddles first)\n"
		..WEPHELP_ALTRELOAD.."  Reload (pockets only)\n"
		..(weaponstatus[0]&HUNTF_EXPORT?"":(WEPHELP_FIREMODE.."  Pump/Semi"..(weaponstatus[0]&HUNTF_CANFULLAUTO?"/Auto":"").."\n"))
		..WEPHELP_FIREMODE.."+"..WEPHELP_RELOAD.."  Load side saddles\n"
		..WEPHELP_USE.."+"..WEPHELP_UNLOAD.."  Steal ammo from Slayer\n"
		..WEPHELP_UNLOADUNLOAD
		;
	}
	override void DrawSightPicture(
		HDStatusBar sb,HDWeapon hdw,HDPlayerPawn hpl,
		bool sightbob,vector2 bob,double fov,bool scopeview,actor hpc,string whichdot
	){
		int cx,cy,cw,ch;
		[cx,cy,cw,ch]=screen.GetClipRect();
		sb.SetClipRect(
			-16+bob.x,-4+bob.y,32,16,
			sb.DI_SCREEN_CENTER
		);
		vector2 bobb=bob*3;
		bobb.y=clamp(bobb.y,-8,8);
		sb.drawimage(
			"frntsite",(0,0)+bobb,sb.DI_SCREEN_CENTER|sb.DI_ITEM_TOP,
			alpha:0.9
		);
		sb.SetClipRect(cx,cy,cw,ch);
		sb.drawimage(
			"backsite",(0,0)+bob,sb.DI_SCREEN_CENTER|sb.DI_ITEM_TOP
		);
	}
	override double gunmass(){
		int tube=weaponstatus[HUNTS_TUBE];
		if(tube>4)tube+=(tube-4)*2;
		return 8+tube*0.3+weaponstatus[SHOTS_SIDESADDLE]*0.08;
	}
	override double weaponbulk(){
		return 125+(weaponstatus[SHOTS_SIDESADDLE]+weaponstatus[HUNTS_TUBE])*ENC_SHELLLOADED;
	}
	action void A_SwitchFireMode(bool forwards=true){
		if(invoker.weaponstatus[0]&HUNTF_EXPORT){
			invoker.weaponstatus[HUNTS_FIREMODE]=0;
			return;
		}
		int newfm=invoker.weaponstatus[HUNTS_FIREMODE]+(forwards?1:-1);
		int newmax=(invoker.weaponstatus[0]&HUNTF_CANFULLAUTO)?2:1;
		if(newfm>newmax)newfm=0;
		else if(newfm<0)newfm=newmax;
		invoker.weaponstatus[HUNTS_FIREMODE]=newfm;
	}
	action void A_SetAltHold(bool which){
		if(which)invoker.weaponstatus[0]|=HUNTF_ALTHOLDING;
		else invoker.weaponstatus[0]&=~HUNTF_ALTHOLDING;
	}
	action void A_Chamber(bool careful=false){
		int chm=invoker.weaponstatus[HUNTS_CHAMBER];
		invoker.weaponstatus[HUNTS_CHAMBER]=0;
		if(invoker.weaponstatus[HUNTS_TUBE]>0){
			invoker.weaponstatus[HUNTS_CHAMBER]=2;
			invoker.weaponstatus[HUNTS_TUBE]--;
		}
		vector3 cockdir;double cp=cos(pitch);
		if(careful)cockdir=(-cp,cp,-5);
		else cockdir=(0,-cp*5,sin(pitch)*frandom(4,6));
		cockdir.xy=rotatevector(cockdir.xy,angle);
		actor fbs;bool gbg;
		if(chm>1){
			if(careful&&!A_JumpIfInventory("HDShellAmmo",0,"null")){
				HDF.Give(self,"HDShellAmmo",1);
			}else{
				[gbg,fbs]=A_SpawnItemEx("HDFumblingShell",
					cos(pitch)*8,0,height-8-sin(pitch)*8,
					vel.x+cockdir.x,vel.y+cockdir.y,vel.z+cockdir.z,
					0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH
				);
			}
		}else if(chm>0){	
			cockdir*=frandom(1.,1.3);
			[gbg,fbs]=A_SpawnItemEx("HDSpentShell",
				cos(pitch)*8,frandom(-0.1,0.1),height-8-sin(pitch)*8,
				vel.x+cockdir.x,vel.y+cockdir.y,vel.z+cockdir.z,
				0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH
			);
		}
	}
	action void A_CheckPocketSaddles(){
		if(invoker.weaponstatus[SHOTS_SIDESADDLE]<1)invoker.weaponstatus[0]|=HUNTF_FROMPOCKETS;
		if(!countinv("HDShellAmmo"))invoker.weaponstatus[0]&=~HUNTF_FROMPOCKETS;
	}
	action bool A_LoadTubeFromHand(){
		int hand=invoker.handshells;
		if(
			!hand
			||(
				invoker.weaponstatus[HUNTS_CHAMBER]>0
				&&invoker.weaponstatus[HUNTS_TUBE]>=invoker.tubesize
			)
		){
			EmptyHand();
			return false;
		}
		invoker.weaponstatus[HUNTS_TUBE]++;
		invoker.handshells--;
		A_PlaySound("weapons/huntreload",CHAN_WEAPON);
		return true;
	}
	action bool A_GrabShells(int maxhand=3,bool settics=false,bool alwaysone=false){
		if(maxhand>0)EmptyHand();else maxhand=abs(maxhand);
		bool fromsidesaddles=!(invoker.weaponstatus[0]&HUNTF_FROMPOCKETS);
		int toload=min(
			fromsidesaddles?invoker.weaponstatus[SHOTS_SIDESADDLE]:countinv("HDShellAmmo"),
			alwaysone?1:(invoker.tubesize-invoker.weaponstatus[HUNTS_TUBE]),
			max(1,health/22),
			maxhand
		);
		if(toload<1)return false;
		invoker.handshells=toload;
		if(fromsidesaddles){
			invoker.weaponstatus[SHOTS_SIDESADDLE]-=toload;
			if(settics)A_SetTics(2);
			A_PlaySound("weapons/pocket",CHAN_WEAPON,0.4);
			A_MuzzleClimb(
				frandom(0.1,0.15),frandom(0.05,0.08),
				frandom(0.1,0.15),frandom(0.05,0.08)
			);
		}else{
			A_TakeInventory("HDShellAmmo",toload,TIF_NOTAKEINFINITE);
			if(settics)A_SetTics(7);
			A_PlaySound("weapons/pocket",CHAN_WEAPON);
			A_MuzzleClimb(
				frandom(0.1,0.15),frandom(0.2,0.4),
				frandom(0.2,0.25),frandom(0.3,0.4),
				frandom(0.1,0.35),frandom(0.3,0.4),
				frandom(0.1,0.15),frandom(0.2,0.4)
			);
		}
		return true;
	}
	double shotpowervariation;
	states{
	select0:
		SHTG A 0;
		goto select0big;
	deselect0:
		SHTG A 0;
		goto deselect0big;
	firemode:
		SHTG A 0 a_switchfiremode();
	firemodehold:
		---- A 1{
			if(pressingreload()){
				a_switchfiremode(false); //untoggle
				setweaponstate("reloadss");
			}else A_WeaponReady(WRF_NONE);
		}
		---- A 0 A_JumpIf(pressingfiremode()&&invoker.weaponstatus[SHOTS_SIDESADDLE]<12,"firemodehold");
		goto nope;
	ready:
		SHTG A 0 A_JumpIf(pressingunload()&&(pressinguse()||pressingzoom()),"cannibalize");
		SHTG A 0 A_JumpIf(pressingaltfire(),2);
		SHTG A 0{
			if(!pressingaltfire()){
				if(!pressingfire())A_ClearRefire();
				A_SetAltHold(false);
			}
		}
		SHTG A 1 A_WeaponReady(WRF_ALL);
		goto readyend;
	reloadSS:
		SHTG A 1 offset(1,34);
		SHTG A 2 offset(2,34);
		SHTG A 3 offset(3,36);
	reloadSSrestart:
		SHTG A 6 offset(3,35);
		SHTG A 9 offset(4,34);
		SHTG A 4 offset(3,34){
			int hnd=min(
				countinv("HDShellAmmo"),
				12-invoker.weaponstatus[SHOTS_SIDESADDLE],
				max(1,health/22),
				3
			);
			if(hnd<1)setweaponstate("reloadSSend");
			else{
				A_TakeInventory("HDShellAmmo",hnd);
				invoker.weaponstatus[SHOTS_SIDESADDLE]+=hnd;
				A_PlaySound("weapons/pocket",CHAN_WEAPON);
			}
		}
		SHTG A 0 {
			if(
				!PressingReload()
				&&!PressingAltReload()
			)setweaponstate("reloadSSend");
			else if(
				invoker.weaponstatus[SHOTS_SIDESADDLE]<12
				&&countinv("HDShellAmmo")
			)setweaponstate("ReloadSSrestart");
		}
	reloadSSend:
		SHTG A 3 offset(2,34);
		SHTG A 1 offset(1,34) EmptyHand(careful:true);
		goto nope;
	hold:
		SHTG A 0{
			bool paf=pressingaltfire();
			if(
				paf&&!(invoker.weaponstatus[0]&HUNTF_ALTHOLDING)
			)setweaponstate("chamber");
			else if(!paf)invoker.weaponstatus[0]&=~HUNTF_ALTHOLDING;
		}
		SHTG A 1 A_WeaponReady(WRF_NONE);
		SHTG A 0 A_Refire();
		goto ready;
	fire:
		SHTG A 0 A_JumpIf(invoker.weaponstatus[HUNTS_CHAMBER]==2,"shoot");
		SHTG A 1 A_WeaponReady(WRF_NONE);
		SHTG A 0 A_Refire();
		goto ready;
	shoot:
		SHTG A 2;
		SHTG A 1 offset(0,36){
			actor p=spawn("HDBullet00b",pos+(0,0,height-6),ALLOW_REPLACE);
			p.target=self;p.angle=angle;p.pitch=pitch;
			p.vel+=(
				frandom(-1.,1.),frandom(-1.,1.),frandom(-1.,1.)
			);
			invoker.shotpowervariation=frandom(-10.,10.);
			p.speed+=invoker.shotpowervariation;
			p.vel+=self.vel;


			A_GunFlash();
			invoker.weaponstatus[HUNTS_CHAMBER]=1;
			A_PlaySound("weapons/hunter",CHAN_WEAPON);
			vector2 shotrecoil=(randompick(-1,1),-2.6);
			if(invoker.weaponstatus[HUNTS_FIREMODE]>0)shotrecoil=(randompick(-1,1)*1.4,-3.4);
			A_MuzzleClimb(0,0,shotrecoil.x,shotrecoil.y,randompick(-1,1)*1.,-0.3);
		}
		SHTG E 1;
		SHTG E 0{
			if(
				invoker.weaponstatus[HUNTS_FIREMODE]>0
				&&invoker.shotpowervariation>-9.
			)setweaponstate("chamberauto");
		}goto ready;
	altfire:
	chamber:
		SHTG A 0 A_JumpIf(invoker.weaponstatus[0]&HUNTF_ALTHOLDING,"nope");
		SHTG A 0 A_SetAltHold(true);
		SHTG A 1 A_Overlay(120,"playsgco");
		SHTG AE 1 A_MuzzleClimb(0,frandom(0.6,1.));
		SHTG E 1 A_JumpIf(pressingaltfire(),"longstroke");
		SHTG EA 1 A_MuzzleClimb(0,-frandom(0.6,1.));
		SHTG E 0 A_PlaySound("weapons/huntshort",CHAN_WEAPON);
		SHTG E 0 A_Refire("ready");
		goto ready;
	longstroke:
		SHTG F 2 A_MuzzleClimb(frandom(1.,2.));
		SHTG F 0{
			A_Chamber();
			A_MuzzleClimb(-frandom(1.,2.));
		}
	racked:
		SHTG F 1 A_WeaponReady(WRF_NOFIRE);
		SHTG F 0 A_JumpIf(!pressingaltfire(),"unrack");
		SHTG F 0 A_JumpIf(pressingunload(),"rackunload");
		SHTG F 0 A_JumpIf(invoker.weaponstatus[HUNTS_CHAMBER],"racked");
		SHTG F 0{
			int rld=0;
			if(pressingreload()){
				rld=1;
				if(invoker.weaponstatus[SHOTS_SIDESADDLE]>0)
				invoker.weaponstatus[0]&=~HUNTF_FROMPOCKETS;
				else{
					invoker.weaponstatus[0]|=HUNTF_FROMPOCKETS;
					rld=2;
				}
			}else if(pressingaltreload()){
				rld=2;
				invoker.weaponstatus[0]|=HUNTF_FROMPOCKETS;
			}
			if(
				(rld==2&&countinv("HDShellAmmo"))
				||(rld==1&&invoker.weaponstatus[SHOTS_SIDESADDLE]>0)
			)setweaponstate("rackreload");
		}
		loop;
	rackreload:
		SHTG F 1 offset(-1,35);
		SHTG F 2 offset(-2,37);
		SHTG F 4 offset(-3,40) A_WeaponBusy(false);
		SHTG F 1 offset(-4,42) A_GrabShells(1,true,true);
		SHTG F 0 A_JumpIf(!(invoker.weaponstatus[0]&HUNTF_FROMPOCKETS),"rackloadone");
		SHTG F 6 offset(-5,43);
		SHTG F 6 offset(-4,41) A_PlaySound("weapons/pocket",CHAN_WEAPON);
	rackloadone:
		SHTG F 1 offset(-4,42);
		SHTG F 2 offset(-4,41);
		SHTG F 3 offset(-4,40){
			A_PlaySound("weapons/huntreload",CHAN_WEAPON);
			invoker.weaponstatus[HUNTS_CHAMBER]=2;
			invoker.handshells--;
			EmptyHand(careful:true);
			A_WeaponBusy(false);
		}
		SHTG F 5 offset(-4,41);
		SHTG F 4 offset(-4,40) A_JumpIf(invoker.handshells>0,"rackloadone");
		goto rackreloadend;
	rackreloadend:
		SHTG F 1 offset(-3,39);
		SHTG F 1 offset(-2,37);
		SHTG F 1 offset(-1,34);
		goto racked;

	rackunload:
		SHTG F 1 offset(-1,35);
		SHTG F 2 offset(-2,37);
		SHTG F 4 offset(-3,40) A_WeaponBusy(false);
		SHTG F 1 offset(-4,42);
		SHTG F 2 offset(-4,41);
		SHTG F 3 offset(-4,40){
			int chm=invoker.weaponstatus[HUNTS_CHAMBER];
			invoker.weaponstatus[HUNTS_CHAMBER]=0;
			if(chm==2){
				invoker.handshells++;
				EmptyHand(careful:true);
			}else if(chm==1)A_SpawnItemEx("HDSpentShell",
				cos(pitch)*8,0,height-7-sin(pitch)*8,
				vel.x+cos(pitch)*cos(angle-random(86,90))*5,
				vel.y+cos(pitch)*sin(angle-random(86,90))*5,
				vel.z+sin(pitch)*random(4,6),
				0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH
			);
			if(chm)A_PlaySound("weapons/huntreload",CHAN_WEAPON);
			A_WeaponBusy(false);
		}
		SHTG F 5 offset(-4,41);
		SHTG F 4 offset(-4,40) A_JumpIf(invoker.handshells>0,"rackloadone");
		goto rackreloadend;

	unrack:
		SHTG F 0 A_Overlay(120,"playsgco2");
		SHTG E 1 A_JumpIf(!pressingfire(),1);
		SHTG EA 2{
			if(pressingfire())A_SetTics(1);
			A_MuzzleClimb(0,-frandom(0.6,1.));
		}
		SHTG A 0 A_ClearRefire();
		goto ready;
	playsgco:
		TNT1 A 8 A_PlaySound("weapons/huntrackup",5);
		TNT1 A 0 A_StopSound(5);
		stop;
	playsgco2:
		TNT1 A 8 A_PlaySound("weapons/huntrackdown",5);
		TNT1 A 0 A_StopSound(5);
		stop;
	chamberauto:
		SHTG A 1 A_Chamber();
		SHTG A 1 A_JumpIf(invoker.weaponstatus[0]&HUNTF_CANFULLAUTO&&invoker.weaponstatus[HUNTS_FIREMODE]==2,"ready");
		SHTG A 0 A_Refire();
		goto ready;
	flash:
		SHTF B 1 bright{
			A_Light2();
			HDFlashAlpha(-32);
		}
		TNT1 A 1 A_ZoomRecoil(0.9);
		TNT1 A 0 A_Light0();
		TNT1 A 0 A_AlertMonsters();
		stop;
	altreload:
	reloadfrompockets:
		SHTG A 0{
			int ppp=countinv("HDShellAmmo");
			if(ppp<1)setweaponstate("nope");
				else if(ppp<1)
					invoker.weaponstatus[0]&=~HUNTF_FROMPOCKETS;
				else invoker.weaponstatus[0]|=HUNTF_FROMPOCKETS;
		}goto startreload;
	reload:
	reloadfromsidesaddles:
		SHTG A 0{
			int sss=invoker.weaponstatus[SHOTS_SIDESADDLE];
			int ppp=countinv("HDShellAmmo");
			if(ppp<1&&sss<1)setweaponstate("nope");
				else if(sss<1)
					invoker.weaponstatus[0]|=HUNTF_FROMPOCKETS;
				else invoker.weaponstatus[0]&=~HUNTF_FROMPOCKETS;
		}goto startreload;
	startreload:
		SHTG A 1{
			if(
				invoker.weaponstatus[HUNTS_TUBE]>=invoker.tubesize
			){
				if(
					invoker.weaponstatus[SHOTS_SIDESADDLE]<12
					&&countinv("HDShellAmmo")
				)setweaponstate("ReloadSS");
				else setweaponstate("nope");
			}
		}
		SHTG AB 4 A_MuzzleClimb(frandom(.6,.7),-frandom(.6,.7));
		SHTG B 0 A_PlaySound("weapons/huntopen",CHAN_WEAPON);
	reloadstarthand:
		SHTG C 1 offset(0,36);
		SHTG C 1 offset(0,38);
		SHTG C 2 offset(0,36);
		SHTG C 2 offset(0,34);
		SHTG C 3 offset(0,36);
		SHTG C 3 offset(0,40) A_CheckPocketSaddles();
		SHTG C 0 A_JumpIf(invoker.weaponstatus[0]&HUNTF_FROMPOCKETS,"reloadpocket");
	reloadfast:
		SHTG C 4 offset(0,40) A_GrabShells(3,false);
		SHTG C 3 offset(0,42);
		SHTG C 3 offset(0,41);
		goto reloadashell;
	reloadpocket:
		SHTG C 4 offset(0,39) A_GrabShells(3,false);
		SHTG C 6 offset(0,40) A_JumpIf(health>40,1);
		SHTG C 4 offset(0,40) A_PlaySound("weapons/pocket",CHAN_WEAPON);
		SHTG C 8 offset(0,42) A_PlaySound("weapons/pocket",CHAN_WEAPON);
		SHTG C 6 offset(0,41) A_PlaySound("weapons/pocket",CHAN_WEAPON);
		SHTG C 6 offset(0,40);
		goto reloadashell;
	reloadashell:
		SHTG C 2 offset(0,36)A_PlaySound("weapons/huntreload",CHAN_WEAPON);
		SHTG C 4 offset(0,34)A_LoadTubeFromHand();
		SHTG CCCCCC 1 offset(0,33){
			if(
				PressingReload()
				||PressingAltReload()
				||PressingUnload()
				||PressingFire()
				||PressingAltfire()
				||PressingZoom()
				||PressingFiremode()
			)invoker.weaponstatus[0]|=HUNTF_HOLDING;
			else invoker.weaponstatus[0]&=~HUNTF_HOLDING;

			if(
				invoker.weaponstatus[HUNTS_TUBE]>=invoker.tubesize
				||(
					invoker.handshells<1&&(
						invoker.weaponstatus[0]&HUNTF_FROMPOCKETS
						||invoker.weaponstatus[SHOTS_SIDESADDLE]<1
					)&&
					!countinv("HDShellAmmo")
				)
			)setweaponstate("reloadend");
			else if(
				!pressingaltreload()
				&&!pressingreload()
			)setweaponstate("reloadend");
			else if(invoker.handshells<1)setweaponstate("reloadstarthand");
		}goto reloadashell;
	reloadend:
		SHTG C 5 offset(0,34) A_PlaySound("weapons/huntopen",CHAN_WEAPON);
		SHTG C 1 offset(0,36) EmptyHand(careful:true);
		SHTG C 1 offset(0,34);
		SHTG CBA 3;
		SHTG A 0 A_JumpIf(invoker.weaponstatus[0]&HUNTF_HOLDING,"nope");
		goto ready;

	cannibalize:
		SHTG A 2 offset(0,36) A_JumpIf(!countinv("Slayer"),"nope");
		SHTG A 2 offset(0,40) A_PlaySound("weapons/pocket",CHAN_WEAPON);
		SHTG A 6 offset(0,42);
		SHTG A 4 offset(0,44);
		SHTG A 6 offset(0,42);
		SHTG A 2 offset (0,36) A_CannibalizeOtherShotgun();
		goto ready;

	unloadSS:
		SHTG A 2 offset(1,34) A_JumpIf(invoker.weaponstatus[SHOTS_SIDESADDLE]<1,"nope");
		SHTG A 1 offset(2,34);
		SHTG A 1 offset(3,36);
	unloadSSLoop1:
		SHTG A 4 offset(4,36);
		SHTG A 2 offset(5,37) A_UnloadSideSaddle(SHOTS_SIDESADDLE);
		SHTG A 3 offset(4,36){	//decide whether to loop
			if(
				PressingReload()
				||PressingFire()
				||PressingAltfire()
				||invoker.weaponstatus[SHOTS_SIDESADDLE]<1
			)setweaponstate("unloadSSend");
		}goto unloadSSLoop1;
	unloadSSend:
		SHTG A 3 offset(4,35);
		SHTG A 2 offset(3,35);
		SHTG A 1 offset(2,34);
		SHTG A 1 offset(1,34);
		goto nope;
	unload:
		SHTG A 1{
			if(
				invoker.weaponstatus[SHOTS_SIDESADDLE]>0
				&&!(player.cmd.buttons&BT_USE)
			)setweaponstate("unloadSS");
			else if(
				invoker.weaponstatus[HUNTS_CHAMBER]<1
				&&invoker.weaponstatus[HUNTS_TUBE]<1
			)setweaponstate("nope");
		}
		SHTG BC 4 A_MuzzleClimb(frandom(1.2,2.4),-frandom(1.2,2.4));
		SHTG C 1 offset(0,34);
		SHTG C 1 offset(0,36) A_PlaySound("weapons/huntopen",CHAN_WEAPON);
		SHTG C 1 offset(0,38);
		SHTG C 4 offset(0,36){
			A_MuzzleClimb(-frandom(1.2,2.4),frandom(1.2,2.4));
			if(invoker.weaponstatus[HUNTS_CHAMBER]<1){
				setweaponstate("unloadtube");
			}else A_PlaySound("weapons/huntrack",5);
		}
		SHTG D 8 offset(0,34){
			A_MuzzleClimb(-frandom(1.2,2.4),frandom(1.2,2.4));
			int chm=invoker.weaponstatus[HUNTS_CHAMBER];
			invoker.weaponstatus[HUNTS_CHAMBER]=0;
			if(chm>1){
				A_PlaySound("weapons/huntreload",CHAN_WEAPON);
				if(A_JumpIfInventory("HDShellAmmo",0,"null"))A_SpawnItemEx("HDFumblingShell",
					cos(pitch)*8,0,height-7-sin(pitch)*8,
					vel.x+cos(pitch)*cos(angle-random(86,90))*5,
					vel.y+cos(pitch)*sin(angle-random(86,90))*5,
					vel.z+sin(pitch)*random(4,6),
					0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH
				);else{
					HDF.Give(self,"HDShellAmmo",1);
					A_PlaySound("weapons/pocket",CHAN_BODY);
					A_SetTics(5);
				}
			}else if(chm>0)A_SpawnItemEx("HDSpentShell",
				cos(pitch)*8,0,height-7-sin(pitch)*8,
				vel.x+cos(pitch)*cos(angle-random(86,90))*5,
				vel.y+cos(pitch)*sin(angle-random(86,90))*5,
				vel.z+sin(pitch)*random(4,6),
				0,SXF_ABSOLUTEMOMENTUM|SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH
			);
		}
		SHTG C 0 A_JumpIf(!pressingunload(),"reloadend");
		SHTG C 4 offset(0,40);
	unloadtube:
		SHTG C 6 offset(0,40) EmptyHand(careful:true);
	unloadloop:
		SHTG C 8 offset(1,41){
			if(invoker.weaponstatus[HUNTS_TUBE]<1)setweaponstate("reloadend");
			else if(invoker.handshells>=3)setweaponstate("unloadloopend");
			else{
				invoker.handshells++;
				invoker.weaponstatus[HUNTS_TUBE]--;
			}
		}
		SHTG C 4 offset(0,40) A_PlaySound("weapons/huntreload",CHAN_WEAPON);
		loop;
	unloadloopend:
		SHTG C 6 offset(1,41);
		SHTG C 3 offset(1,42){
			int rmm=ammocap("HDShellAmmo")-countinv("HDShellAmmo");
			if(rmm>0){
				A_PlaySound("weapons/pocket");
				A_SetTics(8);
				HDF.Give(self,"HDShellAmmo",min(rmm,invoker.handshells));
				invoker.handshells=max(invoker.handshells-rmm,0);
			}
		}
		SHTG C 0 EmptyHand(careful:true);
		SHTG C 6 A_Jumpif(!pressingunload(),"reloadend");
		goto unloadloop;
	spawn:
		HUNT ABCDEFG -1 nodelay{
			int ssh=invoker.weaponstatus[SHOTS_SIDESADDLE];
			if(ssh>=11)frame=0;
			else if(ssh>=9)frame=1;
			else if(ssh>=7)frame=2;
			else if(ssh>=5)frame=3;
			else if(ssh>=3)frame=4;
			else if(ssh>=1)frame=5;
			else frame=6;
		}
	}
	override void InitializeWepStats(bool idfa){
		weaponstatus[HUNTS_CHAMBER]=2;
		weaponstatus[HUNTS_TUBE]=idfa?tubesize:7;
		weaponstatus[SHOTS_SIDESADDLE]=12;
		handshells=0;
	}
	override void loadoutconfigure(string input){
		int type=getloadoutvar(input,"type",1);
		switch(type){
		case 0:
			weaponstatus[0]|=HUNTF_EXPORT;
			weaponstatus[0]&=~HUNTF_CANFULLAUTO;
			break;
		case 1:
			weaponstatus[0]&=~HUNTF_EXPORT;
			weaponstatus[0]&=~HUNTF_CANFULLAUTO;
			break;
		case 2:
			weaponstatus[0]&=~HUNTF_EXPORT;
			weaponstatus[0]|=HUNTF_CANFULLAUTO;
			break;
		default:
			break;
		}
		int firemode=getloadoutvar(input,"firemode",1);
		if(firemode>=0)weaponstatus[HUNTS_FIREMODE]=clamp(firemode,0,type);
	}
}
enum hunterstatus{
	HUNTF_CANFULLAUTO=1,
	HUNTF_JAMMED=2,
	HUNTF_UNLOADONLY=4,
	HUNTF_FROMPOCKETS=8,
	HUNTF_ALTHOLDING=16,
	HUNTF_HOLDING=32,
	HUNTF_EXPORT=64,

	HUNTS_FIREMODE=1,
	HUNTS_CHAMBER=2,
	//3 is for side saddles
	HUNTS_TUBE=4,
	HUNTS_HEAT=5,
	HUNTS_HAND=6,
};

