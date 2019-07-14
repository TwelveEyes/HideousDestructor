//-------------------------------------------------
// Blood Substitute
//-------------------------------------------------
class SecondBlood:HDWeapon{
	default{
		//$Category "Items/Hideous Destructor/Supplies"
		//$Title "Synhetic Blood"
		//$Sprite "PBLDA0"

		scale 0.5;
		-hdweapon.droptranslation
		+weapon.wimpy_weapon
		+inventory.invbar
		+hdweapon.fitsinbackpack
		weapon.selectionorder 1012;
		inventory.pickupmessage "Picked up a synthblood pack.";
		inventory.icon "PBLDA0";
		hdweapon.nicename "Synthetic Blood";
		hdweapon.refid HDLD_BLODPAK;
		inventory.pickupsound "weapons/pocket";
		species "HealingItem";
	}
	override bool AddSpareWeapon(actor newowner){return AddSpareWeaponRegular(newowner);}
	override hdweapon GetSpareWeapon(actor newowner,bool reverse,bool doselect){return GetSpareWeaponRegular(newowner,reverse,doselect);}
	override double weaponbulk(){
		return ENC_STIMPACK;
	}
	override string gethelptext(){
		return "\cuSynthetic Blood\n"
		..WEPHELP_FIRE.."  Attach"
		..(owner.countinv("BloodBagWorn")?"\n"..WEPHELP_ALTRELOAD.."  Remove":"")
	;}
	states{
	spawn:
		PBLD A -1;
		stop;
	select:
		TNT1 A 10{
			if(getcvar("hd_helptext"))
			A_WeaponMessage("\cr::: \cgSECOND BLOOD \cr:::\c-\n\n\nPress and hold Fire\nto attach.",175);
		}
		goto super::select;
	altreload:
	unload:
		TNT1 A 0 A_PlaySound("weapons/pocket",CHAN_BODY);
		TNT1 A 15 A_JumpIf(!countinv("BloodBagWorn")||countinv("WornRadsuit"),"nope");
		TNT1 A 10{
			A_DropInventory("BloodBagWorn");
			A_ClearRefire();
		}goto nope;
	reload:
		TNT1 A 14 A_DropInventory("HDArmourWorn");
		TNT1 A 0 A_Refire();
		goto readyend;
	ready:
		TNT1 A 1 A_WeaponReady(WRF_ALLOWRELOAD|WRF_ALLOWUSER1|WRF_ALLOWUSER4);
		goto readyend;
	fire:
	altfire:
		TNT1 A 10 A_PlaySound("bloodpack/open");
		TNT1 AAA 8 A_PlaySound("bloodpack/shake",CHAN_WEAPON);
		TNT1 A 4;
		TNT1 A 0 A_Refire();
		goto ready;
	hold:
	althold:
		TNT1 A 1{
			hdplayerpawn patient=null;
			int bt=player.cmd.buttons;
			if(bt&BT_ATTACK){
				patient=hdplayerpawn(self);
				A_MuzzleClimb(frandom(-0.3,0.3),pitch<45?0.4:0.);
			}else if(bt&BT_ALTATTACK){
				//get the patient
				flinetracedata blt;
				LineTrace(
					angle,
					32,
					pitch,
					0,
					offsetz:height-10.,
					data:blt
				);
				actor tracbak=invoker.tracer;
				invoker.tracer=blt.hitactor;
				if(
					!tracbak
					||tracbak!=blt.hitactor
					||!hdplayerpawn(tracbak)
				){
					A_WeaponMessage("Can't reach patient.");
					invoker.weaponstatus[SBS_INJECTCOUNTER]=0;
					return;
				}
				patient=hdplayerpawn(tracbak);
			}
			if(patient)invoker.weaponstatus[SBS_INJECTCOUNTER]++;else{
				invoker.weaponstatus[SBS_INJECTCOUNTER]=0;
				return;
			}
			if(
				patient.countinv("WornRadsuit")
				||patient.countinv("HDArmourWorn")
			){
				if(
					bt&BT_ATTACK
					&&getcvar("hd_autostrip")
				){
					setweaponstate("reload");
				}else{
					A_WeaponMessage("Remove "..((bt&BT_ALTATTACK)?"their":"your").." armour first.");
					invoker.weaponstatus[SBS_INJECTCOUNTER]=0;
				}
				return;
			}
			if(
				patient.countinv("BloodBagWorn")
			){
				A_WeaponMessage(((bt&BT_ALTATTACK)?"Patient has":"You have").." a blood injector already!");
				invoker.weaponstatus[SBS_INJECTCOUNTER]=0;
				return;
			}
			if(invoker.weaponstatus[SBS_INJECTCOUNTER]>30){
				patient.A_GiveInventory("BloodBagWorn");
				A_PlaySound("bloodbag/inject",CHAN_WEAPON);
				A_SetBlend("7a 3a 18",0.1,4);
				A_SetPitch(pitch+2,SPF_INTERPOLATE);
				hdweaponselector.select(self,"HDFist");
				setweaponstate("nope");
				dropinventory(invoker);
				invoker.goawayanddie();
			}
		}
		TNT1 A 0 A_Refire();
		goto ready;
	}
	enum SecondBloodNums{
		SBS_INJECTCOUNTER=1,
	}
}
class BloodBagWorn:Inventory{
	int bloodleft;
	default{
		-solid -noblockmap
		+rollsprite
		inventory.maxamount 1;
		height 2;radius 2;
		scale 0.5;
	}
	override void postbeginplay(){
		super.postbeginplay();
		bloodleft=256;
	}
	override void touch(actor toucher){}
	override inventory createtossable(int amount){
		let onr=hdplayerpawn(owner);
		if(
			onr
			&&onr.player
		){
			if(
				!onr.player.readyweapon
				||(
					!(onr.player.readyweapon is "HDWoundFixer")
					&&!(onr.player.readyweapon is "SecondBlood")
				)
			)onr.woundcount++;
			else onr.oldwoundcount++;
		}
		return super.createtossable(amount);
	}
	override void DoEffect(){
		let hp=HDPlayerPawn(owner);
		if(!hp){destroy();return;}
		if(!hp.beatcount&&bloodleft>0){
			bloodleft--;
			hp.bledout=max(0,hp.bledout-4);
			if(hp.fatigue<HDCONST_SPRINTFATIGUE)hp.fatigue++;
		}
		//fall off
		if(hp.inpain>0&&!random(0,31))hp.dropinventory(self);
	}
	states{
	spawn:
		PBLD B 0 nodelay{
			if(!random(0,1))scale.x=-scale.x;
			roll=frandom(-20,20);
		}
		PBLD B 3{
			if(bloodleft>0){
				if(floorz==pos.z&&vel!=(0,0,0))A_SpawnItemEx("HDBloodTrailFloor");
				if(!(level.time%2))bloodleft--;
				angle+=frandom(3,6);
				A_SpawnParticle("red",
					SPF_RELATIVE,70,frandom(1.6,1.9),0,
					0,2,4,
					frandom(-0.4,0.4),frandom(-0.4,0.4),frandom(5.,5.2),
					frandom(-0.1,0.1),frandom(-0.1,0.1),-1.
				);
			}
		}
		wait;
	}
}
