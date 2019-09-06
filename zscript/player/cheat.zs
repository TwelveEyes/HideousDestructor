//-------------------------------------------------
// [insert homestar reference here]
//-------------------------------------------------
extend class HDPlayerPawn{
	//cheats to give or take away bad stuff
	bool cheatgivestatusailments(string name,int amount=1){
		if(name~=="fire"){
			if(!scopecamera){
				scopecamera=spawn("ScopeCamera",pos,ALLOW_REPLACE);
				scopecamera.target=self;
			}
			let hdsc=hdactor(scopecamera);
			if(hdsc)hdsc.A_Immolate(self,self,amount);
		}
		if(name~=="wound"||name~=="wounds"){
			woundcount+=amount;return true;
		}
		if(name~=="oldwound"||name~=="oldwounds"||name~=="oldwoundcount"){
			oldwoundcount+=amount;return true;
		}
		if(name~=="unstablewound"||name~=="unstablewounds"||name~=="unstablewoundcount"){
			unstablewoundcount+=amount;return true;
		}
		if(name~=="burn"||name~=="burns"||name~=="burncount"){
			burncount+=amount;return true;
		}
		if(name~=="aggro"||name~=="aggravateddamage"){
			aggravateddamage+=amount;return true;
		}
		if(name~=="stun"){
			stunned+=amount;return true;
		}
		if(name~=="zerk"){
			zerk+=amount;return true;
		}
		return false;
	}
	override void CheatGive(string name, int amount){
		let player=self.player;
		if(!player.mo||player.health<1)return;

		if(cheatgivestatusailments(name,amount)) return;

		bool allthings=(name~=="all"||name~=="everything");

		//apply giveammo principles to HDAmmo
		class<inventory> type;
		if(allthings||name~=="ammo"){
			A_GiveInventory("HDBackpack");
			for(int i=0;i<AllActorClasses.Size();++i){
				type=(class<HDAmmo>)(AllActorClasses[i]);
				if(!type)continue;
				if(
					!getdefaultbytype((class<HDPickup>)(type)).bcheatnogive
					&&getdefaultbytype((class<HDAmmo>)(type)).nicename!=""
				){
					let ammoitem=hdpickup(findinventory(type));
					if(!ammoitem)ammoitem=hdpickup(GiveInventoryType(type));
					ammoitem.amount=max(1,ammoitem.amount,ammoitem.effectivemaxamount());
					let magammoitem=hdmagammo(ammoitem);
					if(magammoitem)magammoitem.maxcheat();
				}
			}
		}

		//just work around armour
		if(allthings||name~=="armor"||name~=="armour"){
			A_TakeInventory("HDArmourWorn");
			A_GiveInventory("BattleArmourWorn");
			return;
		}

		//super call
		super.cheatgive(name,amount);

		//load weapons that use variables instead of ammo types
		if(allthings||name~=="ammo"){
			for(inventory hdww=inv;hdww!=null;hdww=hdww.inv){
				let hdw=hdweapon(hdww);
				if(hdw)hdw.initializewepstats(true);
			}
		}

		//clean up some stuff
		A_TakeInventory("backpack");
		A_TakeInventory("BasicArmor");
	}
	override void CheatTake(string name, int amount){
		if(!cheatgivestatusailments(name,-amount))super.cheattake(name,amount);
	}
}
