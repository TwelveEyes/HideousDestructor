//-------------------------------------------------
// Environment/Radiation Suit
//-------------------------------------------------
class WornRadsuit:InventoryFlag{
	default{-inventory.untossable}
	states{spawn:TNT1 A 0;stop;}
	override inventory createtossable(int amount){
		let rrr=owner.findinventory("PortableRadsuit");
		if(rrr)owner.useinventory(rrr);else destroy();
		return null;
	}
	override void attachtoowner(actor owner){	
		if(!owner.countinv("PortableRadsuit"))owner.A_GiveInventory("PortableRadsuit");
		super.attachtoowner(owner);
	}
	override void DetachFromOwner(){
		owner.A_TakeInventory("PortableRadsuit",1);
		owner.A_PlaySound("weapons/pocket",CHAN_AUTO);
		let onr=HDPlayerPawn(self);
		if(onr)onr.stunned+=60;
		super.DetachFromOwner();
	}
	override void DoEffect(){
		if(stamina>0)stamina--;
	}
}
class PortableRadsuit:HDPickup replaces RadSuit{
	default{
		//$Category "Gear/Hideous Destructor/Supplies"
		//$Title "Environment Suit"
		//$Sprite "SUITA0"

		inventory.maxamount 7;
		inventory.pickupmessage "Environmental shielding suit.";
		inventory.pickupsound "weapons/pocket";
		inventory.icon "SUITB0";
		hdpickup.bulk ENC_RADSUIT;
		hdpickup.nicename "Environment Suit";
		hdpickup.refid HDLD_RADSUIT;
	}
	override void DetachFromOwner(){
		owner.A_TakeInventory("WornRadsuit");
		target=owner;
		super.DetachFromOwner();
	}
	override void actualpickup(actor user){
		HDF.TransferFire(self,user);
		super.actualpickup(user);
	}
	states{
	spawn:
		SUIT A 1;
		SUIT A -1{
			if(!target)return;
			HDF.TransferFire(target,self);
		}
	use:
		TNT1 A 0{
			A_PlaySound("weapons/pocket");
			if(countinv("HDBackpack")){
				A_DropInventory("HDBackpack");
				return;
			}
			A_SetBlend("00 00 00",1,6,"00 00 00");
			A_ChangeVelocity(0,0,2);
			let onr=HDPlayerPawn(self);
			if(onr)onr.stunned+=60;
			if(!countinv("WornRadsuit")){
				int fff=HDF.TransferFire(self,self);
				if(fff){
					if(random(1,fff)>30){
						A_PlaySound("misc/fwoosh",CHAN_AUTO);
						A_TakeInventory("PortableRadsuit",1);
						return;
					}else{
						HDF.TransferFire(self,null);
						if(onr){
							onr.fatigue+=fff;
							onr.stunned+=fff;
						}
					}
				}
				A_GiveInventory("WornRadsuit");
			}else{
				actor a;int b;
				inventory wrs=findinventory("wornradsuit");
				[b,a]=A_SpawnItemEx("PortableRadsuit",0,0,height/2,2,0,4);
				if(a &&  wrs){
					//transfer sticky fire
					if(wrs.stamina){
						let aa=HDActor(a);
						if(aa)aa.A_Immolate(a,self,wrs.stamina);
					}
					//transfer heat
					let hhh=heat(findinventory("heat"));
					if(hhh){
						double realamount=hhh.realamount;
						double intosuit=clamp(realamount*0.9,0,min(200,realamount));
						let hhh2=heat(a.GiveInventoryType("heat"));
						if(hhh2){
							hhh2.realamount+=intosuit;
							hhh.realamount=max(0,hhh.realamount-intosuit);
						}
					}
				}
				A_TakeInventory("WornRadsuit");
			}
		}fail;
	}
}


//-------------------------------------------------
// Light Amplification Visor
//-------------------------------------------------
class PortableLiteAmp:HDPickup replaces Infrared{
	default{
		//$Category "Gear/Hideous Destructor/Supplies"
		//$Title "Light Amp"
		//$Sprite "PVISB0"

		inventory.maxamount 1;
		inventory.interhubamount 1;
		inventory.pickupmessage "Light amplification visor.";
		inventory.icon "PVISA0";
		scale 0.5;
		hdpickup.bulk ENC_LITEAMP;
		hdpickup.nicename "Lite-Amp Goggles";
		hdpickup.refid HDLD_LITEAMP;
	}
	int spent;bool worn;
	int brokenness; //400=totally broken
	PointLight nozerolight;
	override double getbulk(){return bulk;}
	override void DetachFromOwner(){
		worn=false;
		if(owner&&owner.player){
			if(cvar.getcvar("hd_nv",owner.player).getfloat()==999.){
				if(owner.player.fixedcolormap==5)owner.player.fixedcolormap=-1;
				owner.player.fixedlightlevel=-1;
			}
			Shader.SetEnabled(owner.player,"NiteVis",false);
		}
		super.DetachFromOwner();
	}
	double amplitude;
	double lastcvaramplitude;
	override int getsbarnum(int flags){return amplitude;}
	override void AttachToOwner(actor other){
		super.AttachToOwner(other);
		if(owner&&owner.player)amplitude=cvar.getcvar("hd_nv",owner.player).getfloat();
		else amplitude=frandom(-NITEVIS_MAX,NITEVIS_MAX);
		lastcvaramplitude=amplitude;
	}
	override void DoEffect(){
		super.DoEffect();
		if(owner && owner.player){
			bool oldliteamp=(
				(sv_cheats||!multiplayer)
				&&cvar.getcvar("hd_nv",owner.player).getfloat()==999.
			);
			if(
				worn
				&&!owner.countinv("PowerInvisibility")
				&&(!oldliteamp||owner.player.fixedcolormap<0||owner.player.fixedcolormap==5)
			){

				//check if totally drained
				if(HDMagAmmo.NothingLoaded(owner,"HDBattery")){
					owner.A_SetBlend("01 00 00",0.8,16);
					worn=false;
					return;
				}

				//update amplitude if player has set in the console
				double thiscvaramplitude=cvar.getcvar("hd_nv",owner.player).getfloat();
				if(thiscvaramplitude!=lastcvaramplitude){
					lastcvaramplitude=thiscvaramplitude;
					amplitude=thiscvaramplitude;
				}

				let bbb=HDBattery(owner.findinventory("HDBattery"));

				//get the lowest non-empty
				int bbbindex=bbb.mags.size()-1;
				int bbblowest=20;
				for(int i=bbbindex;i>=0;i--){
					if(
						bbb.mags[i]>0
						&&bbb.mags[i]<bbblowest
					){
						bbbindex=i;
						bbblowest=bbb.mags[i];
					}
				}
				int bbbi=bbb.mags[bbbindex];


				//actual goggle effect
				owner.player.fov=min(owner.player.fov,90);
				double nv=min(bbbi*(NITEVIS_MAX/20.),NITEVIS_MAX);
				if(!nv){
					if(thiscvaramplitude<0)amplitude=-0.00001;
					return;
				}
				if(oldliteamp){
					spent+=(NITEVIS_MAX/10);
					owner.player.fixedcolormap=5;
					owner.player.fixedlightlevel=1;
					Shader.SetEnabled(owner.player,"NiteVis",false);
				}else{
					nv=clamp(amplitude,-nv,nv);
					spent+=max(1,nv*0.1);
					Shader.SetEnabled(owner.player,"NiteVis",true);
					Shader.SetUniform1f(owner.player,"NiteVis","exposure",nv);
				}

				//flicker
				if(brokenness>0&&!random[rand1](0,max(0,bbbi*bbbi-brokenness))){
					if(oldliteamp){
						owner.player.fixedcolormap=-1;
						owner.player.fixedlightlevel=-1;
					}
					Shader.SetEnabled(owner.player,"NiteVis",false);
				}

				//drain
				if(spent>NITEVIS_BATCYCLE){
					bbb.mags[bbbindex]=max(0,bbbi-1);
					spent=0;
				}

			}else{
				if(oldliteamp){
					if(owner.player.fixedcolormap==5)owner.player.fixedcolormap=-1;
					owner.player.fixedlightlevel=-1;
				}
				Shader.SetEnabled(owner.player,"NiteVis",false);
			}
		}
	}
	enum NiteVis{
		NITEVIS_BATCYCLE=20000,
		NITEVIS_MAX=100,
	}
	states{
	spawn:
		PVIS B -1;
	use:
		TNT1 A 0{
			int cmd=player.cmd.buttons;
			if(cmd&BT_USE){
				double am=cmd&BT_ZOOM?-5:5;
				double plitude=max(0,(am+abs(invoker.amplitude))%NITEVIS_MAX);
				invoker.amplitude=invoker.amplitude<0?-plitude:plitude;
			}else if(cmd&BT_ZOOM){
				invoker.amplitude=-invoker.amplitude;
			}else{
				A_SetBlend("01 00 00",0.8,16);
				if(HDMagAmmo.NothingLoaded(self,"HDBattery")){
					A_Log("No power for lite-amp. Need at least 1 battery on you.",true);
					invoker.worn=false;
				}
				if(invoker.worn)invoker.worn=false;else{
					invoker.worn=true;
					if(!invoker.nozerolight)invoker.nozerolight=PointLight(spawn("visorlight",pos,ALLOW_REPLACE));
					invoker.nozerolight.target=self;
				}
			}
		}fail;
	}
}
class VisorLight:PointLight{
	override void postbeginplay(){
		super.postbeginplay();
		args[0]=1;
		args[1]=0;
		args[2]=0;
		args[3]=256;
		args[4]=0;
	}
	override void tick(){
		if(!target){
			destroy();
			return;
		}
		if(
			target.findinventory("PortableLiteAmp")
			&&portableliteamp(target.findinventory("PortableLiteAmp")).worn
		)args[3]=256;else args[3]=0;
		setorigin((target.pos.xy,target.pos.z+target.height-6),true);
	}
}

