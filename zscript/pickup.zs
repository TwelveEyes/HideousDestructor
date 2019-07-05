//-------------------------------------------------
// Pickup Archetypes
//-------------------------------------------------
class GrabThinker:Thinker{
	actor picktarget;
	actor pickobj;
	int ticker;
	static void Grab(actor grabber,actor grabee){
		let grabthink=new("GrabThinker");
		grabthink.picktarget=grabber;
		grabthink.pickobj=grabee;
	}
	override void postbeginplay(){
		super.postbeginplay();
	}
	override void ondestroy(){
		if(pickobj)pickobj.bsolid=true;
	}
	override void tick(){
		if(!picktarget||!picktarget.player||!pickobj){destroy();return;}
		super.tick();
		ticker++;
		if(ticker<4){
			pickobj.setorigin(
				0.5*(
					(picktarget.pos+(0,0,picktarget.height-10))
					+pickobj.pos
				),true
			);
			pickobj.bsolid=false;
		}else{
			let pt=hdpickup(pickobj);if(pt)pt.bisbeingpickedup=false;
			let wt=hdweapon(pickobj);
			let ht=hdupk(pickobj);
			let tt=inventory(pickobj);
			if(
				!pickobj
				||!picktarget
				||picktarget.health<1
			){
				destroy();
				return;
			}
			pickobj.A_CallSpecial(
				pickobj.special,pickobj.args[0],
				pickobj.args[1],pickobj.args[2],
				pickobj.args[3],pickobj.args[4]
			);

			vector2 shiftpk=actor.rotatevector((frandom(-0.4,-0.8),frandom(0.8,1.1)),picktarget.angle);
			pickobj.vel.xy+=shiftpk;
			pickobj.setorigin((pickobj.pos.xy+shiftpk,pickobj.pos.z),true);

			if(ht){
				ht.picktarget=picktarget;
				ht.a_hdupkgive();
				destroy();
				return;
			}

			//if backpack is out, try to move into backpack
			if(picktarget.player.readyweapon is "HDBackpack"){
				let bp=HDBackpack(picktarget.findinventory("HDBackpack"));
				if(
					bp
					&&bp==picktarget.player.readyweapon
					&&(
						bp.ItemToBackpack(tt)!=1 //ITB returns 1 if fail to pickup
						||!pickobj //if totally picked up, don't do the rest of the checks
					)
				){
					destroy();
					return;
				}
			}

			//check for pocket space
			if(
				!wt
				&&hdplayerpawn(picktarget)
				&&hdplayerpawn(picktarget).itemenc*hdmath.getencumbrancemult()
					>hdplayerpawn(picktarget).maxpocketspace
				&&(
					!tt
					||(
						!tt.balwayspickup
						&&picktarget.countinv(pickobj.getclassname())
					)
				)
				&&(
					!pt
					||pt.bulk>0
					||(
						hdmagammo(pickobj)&&(
							hdmagammo(pickobj).magbulk>0
							||hdmagammo(pickobj).roundbulk>0
						)
					)
				)
			){
				if(cvar.getcvar("hd_helptext",picktarget.player).getbool())picktarget.A_Log("No room in pockets.",true);
				destroy();
				return;
			}

			//handle actual pickups
			if(pt){
				pt.actualpickup(picktarget);
			}else if(wt){
				wt.actualpickup(picktarget);
			}else if(tt){
				if(picktarget.vel==(0,0,0))picktarget.A_ChangeVelocity(0.001,0,0,CVF_RELATIVE);
			}
			destroy();
			return;
		}
	}
}
class HDPickerUpper:Actor{
	default{
		+solid
		+nogravity
		height 2;
		radius 2;
	}
	override bool cancollidewith(actor other,bool passive){
		return (inventory(other)||hdupk(other));
	}
}

extend class HDPlayerPawn{
	void PickupGrabber(int putimes=-1){
		overloaded=CheckEncumbrance();
		if(!hasgrabbed){
			actor grabbed=null;

			//get an antenna
			hdpickerupper hdpu=null;
			ThinkerIterator hdpuf=ThinkerIterator.Create("HDPickerUpper");
			while(hdpu=HDPickerUpper(hdpuf.Next())){
				if(hdpu.master==self)break;
			}
			if(!hdpu||hdpu.master!=self)hdpu=HDPickerUpper(spawn("HDPickerUpper",pos,ALLOW_REPLACE));
			hdpu.master=self;

			double cp=cos(pitch+3);
			vector3 pudir=2*(cp*cos(angle),cp*sin(angle),-sin(pitch+3));
			hdpu.setorigin((pos.xy,pos.z+height-12),false);
			if(putimes<0)putimes=(pudir.z<0.1)?24:18;
			for(int i=0;i<putimes;i++){
				hdpu.setorigin(hdpu.pos+pudir,false);
				if(
					!hdpu.checkmove(hdpu.pos.xy,PCM_DROPOFF|PCM_NOLINES)
					&&hdpu.blockingmobj
				){
					grabbed=hdpu.blockingmobj;

					//don't hoover the big things
					if(
						grabbed is "HDWeapon"
						||grabbed is "HDMagAmmo"
					)hasgrabbed=true;
				}
			}


			if(
				grabbed
				&&checksight(grabbed)
				&&(
					hdupk(grabbed)
					||inventory(grabbed)
				)
			){
				if(
					grabbed is "hdupk"
					||grabbed is "inventory"
				){
					if(
						grabbed is "hdweapon"
						||(grabbed is "hdpickup"&&!hdpickup(grabbed).bmultipickup)
						||(grabbed is "hdupk"&&!hdupk(grabbed).bmultipickup)
					){
						hasgrabbed=true;
					}
					bool hdupkcustomgrabstate=false;
					if(grabbed is "hdupk"){
						let hdpk=hdupk(grabbed);
						hdpk.picktarget=self;
						if(hdpk.findstate("grab",true)){
							grabbed.setstatelabel("grab");
							hdupkcustomgrabstate=true;
						}
						hdpk.OnGrab(self);
					}
					if(!hdupkcustomgrabstate){
						let hdpg=hdpickup(grabbed);
						if(!hdpg||!hdpg.bisbeingpickedup){
							if(hdpg)hdpg.bisbeingpickedup=true;
							let grabthink=new("GrabThinker");
							grabthink.picktarget=self;
							grabthink.pickobj=grabbed;
						}
					}
				}
			}
		}
	}
}



//Usable pickup.
class HDPickup:CustomInventory{
	int HDPickupFlags;
	flagdef DropTranslation:HDPickupFlags,0;
	flagdef FitsInBackpack:HDPickupFlags,1;
	flagdef MultiPickup:HDPickupFlags,2; //lets you continue picking up without re-pressing the key
	flagdef IsBeingPickedUp:HDPickupFlags,3;
	flagdef CheatNoGive:HDPickupFlags,4;
	flagdef MustShowInMagManager:HDPickupFlags,5;

	actor picktarget;
	double bulk;
	property bulk:bulk;
	int maxunitamount;
	property maxunitamount:maxunitamount;
	string refid;property refid:refid;
	string nicename;property nicename:nicename;
	default{
		+solid
		+inventory.invbar +inventory.persistentpower
		+noblockmonst +notrigger +dontgib

		+hdpickup.droptranslation
		-hdpickup.multipickup
		+hdpickup.fitsinbackpack
		-hdpickup.cheatnogive
		-hdpickup.isbeingpickedup

		inventory.interhubamount int.MAX;
		inventory.maxamount int.MAX;

		hdpickup.bulk 0;
		hdpickup.refid "";
		hdpickup.nicename "";

		radius 8; height 10; scale 0.8;
		inventory.pickupsound "weapons/pocket";
		hdpickup.maxunitamount 1;
	}
	override bool cancollidewith(actor other,bool passive){
		return HDPickerUpper(other);
	}

	//called on level resets, etc.
	virtual void Consolidate(){}

	//called to get the encumbrance
	virtual double getbulk(){return amount*bulk;}
	override inventory createtossable(int amount){
		let onr=owner;
		inventory iii=super.createtossable(amount);
		if(bdroptranslation&&onr){
			if(iii)iii.translation=onr.translation;
		}
		return iii;
	}
	virtual int effectivemaxamount(){
		if(!bulk)return maxamount;
		double gdpsp;
		if(hdplayerpawn(owner))gdpsp=hdplayerpawn(owner).maxpocketspace;
		else gdpsp=getdefaultbytype("hdplayerpawn").maxpocketspace;
		return max(1,gdpsp/bulk);
	}

	override void doeffect(){
		if(!amount)destroy();
	}
	//for the status bar
	virtual ui int getsbarnum(int flags=0){return -1000000;}
	override void touch(actor toucher){}
	virtual void actualpickup(actor other){
		if(!other)other=picktarget;
		if(!other)return;
		if(heat.getamount(self)>50)return;
		name gcn=getclassname();
		int maxtake=HDMath.MaxInv(other,gcn)-other.countinv(gcn);
		if(balwayspickup){
			inventory.touch(other);
			return;
		}else if(maxtake<1){
			return;
		}
		bool gotpickedup=false;
		if(maxtake<amount){
			amount-=maxtake;
			HDF.Give(other,gcn,maxtake);
			gotpickedup=true;
		}else gotpickedup=trypickup(other);
		if(gotpickedup){
			other.A_PlaySound(pickupsound,CHAN_AUTO);
			other.A_Log(string.format("\cg%s",pickupmessage()),true);
		}
	}

	//delete once no longer needed
	void GotoSpawn(){
		if(findstate("spawn2")){
			if(hd_debug)A_Log(string.format("%s still uses spawn2",getclassname()));
			setstatelabel("spawn2");
		}
	}

	//so you don't get a bullet pickup that's 2 bullets somehow
	virtual void SplitPickup(){
		int maxpkamt=max(1,maxunitamount);
		while(amount>maxpkamt){
			let aaa=hdpickup(spawn(getclassname(),pos,ALLOW_REPLACE));
			aaa.amount=maxpkamt;amount-=maxpkamt;
			aaa.vel=vel+(frandom(-1,1),frandom(-1,1),frandom(-1,1));
			if(bdroptranslation)aaa.translation=translation;
		}
		vel+=(frandom(-0.6,0.6),frandom(-0.6,0.6),frandom(-0.6,0.6));
		GotoSpawn();
	}
	override void postbeginplay(){
		maxamount=min(maxamount,effectivemaxamount());
		if(maxunitamount<0)maxunitamount=abs(getdefaultbytype(getclass()).amount);
		itemsthatusethis.clear();
		GetItemsThatUseThis();
		super.postbeginplay();
		if(hdpickup.checkblacklist(self,refid))return;
		let hdps=new("HDPickupSplitter");
		hdps.invoker=self;
	}

	//This is an array of item names created on an actor's initialization.
	//If you have a sub-mod item that also uses a given ammo type,
	//you can use an event handler to add that item to this array for that ammo type.
	//The IsUsed function can, of course, take in any other circumstances you can write in.
	array<string> itemsthatusethis;
	virtual void GetItemsThatUseThis(){}
	virtual bool IsUsed(){return true;}

	//destroy caller if a refid is mentioned in hd_blacklist
	static bool checkblacklist(actor caller,string refid,bool force=false){
		if(refid=="")return false;
		string bl=hd_blacklist;
		bl=bl.makelower();
		if(!force&&bl.left(3)!="all")return false;
		bl.replace(" ","");
		int bldex=bl.rightindexof(refid.makelower());
		// this must use RightIndexOf not IndexOf!
		// consider: "bfg=zrk,zrk=fis" - zerk replaced with none added
		// versus "bfg=zrk,zrk=fis,hrp=zrk" - zerk replaced, then added elsewhere
		// only if the FINAL instance of the refid does not follow "=" that it is truly blacklisted.
		if(bldex>=0){
			string prevchar=bl.mid(bldex-1,1);
			if(prevchar!="="){
				caller.destroy();
				return true;
			}
		}
		return false;
	}

	states{
	use:
		TNT1 A 0;
		fail;
	spawn:
		CLIP A -1;
		stop;
	}
}
class HDPickupSplitter:Thinker{
	hdpickup invoker;
	int ticks;
	override void Tick(){
		super.tick();
		if(!!invoker&&!invoker.owner){
			invoker.SplitPickup();
		}
		destroy();
	}
}

//custom ammotype
class HDAmmo:HDPickup{
	default{
		-inventory.invbar
		-hdpickup.droptranslation
	}
	override bool IsUsed(){
		if(!owner)return true;
		for(int i=0;i<itemsthatusethis.size();i++){
			if(owner.countinv(itemsthatusethis[i]))return true;
		}
		return false;
	}
}



/*
 Fake pickup for creating different actors that give the same item
 hdupk.pickupsound: pickup sound
 hdupk.pickuptype: default type of inventory item it replaces
 hdupk.pickupmessage: self-explanatory
 hdupk.maxunitamount: max # of pickuptype a single unit can store
 hdupk.amount: amount in this item, if it is a container
*/
class HDUPK:HDActor{
	int HDUPKFlags;
	flagdef MultiPickup:HDUPKFlags,0;

	actor picktarget;
	class<inventory> pickuptype;
	string pickupmessage;
	sound pickupsound;
	int maxunitamount;
	int amount;
	property pickuptype:pickuptype;
	property pickupmessage:pickupmessage;
	property pickupsound:pickupsound;
	property maxunitamount:maxunitamount;
	property amount:amount;
	default{
		+solid
		-hdupk.multipickup
		height 8;radius 8;
		hdupk.pickupsound "weapons/pocket";//"misc/i_pkup";
		hdupk.pickupmessage "";
		hdupk.pickuptype "none";
		hdupk.maxunitamount -1;
		hdupk.amount 1;
	}
	override bool cancollidewith(actor other,bool passive){
		return HDPickerUpper(other);
	}
	override void postbeginplay(){
		super.postbeginplay();

		if(!maxunitamount)return;
		if(maxunitamount<0)maxunitamount=abs(getdefaultbytype(getclass()).amount);
		while(amount>maxunitamount){  
			let a=hdupk(spawn(getclassname(),pos,ALLOW_REPLACE));
			a.amount=maxunitamount;
			amount-=maxunitamount;
			a.vel=vel+(frandom(-1,1),frandom(-1,1),frandom(-1,1));
		}
		if(amount>1){  
		}else{
			amount=1;
		}
	}
	virtual void OnGrab(actor grabber){}
	virtual void A_HDUPKGive(){
		//it's not an item container
		if(pickuptype=="none"){
			target=picktarget;
			setstatelabel("give");
			if(!bdestroyed)return;
			picktarget.A_PlaySound(pickupsound,5);
			if(pickupmessage!="")picktarget.A_Log(string.format("\cg%s",pickupmessage),true);
			return;
		}

		//if placing directly into backpack
		if(
			picktarget.player
			&&picktarget.player.readyweapon is "HDBackpack"
		){
			let bp=hdbackpack(picktarget.player.readyweapon);
			int bpindex=bp.invclasses.find(pickuptype.getclassname());
			if(bpindex<bp.invclasses.size()){
				let hdpk=(class<hdpickup>)(pickuptype);
				double defunitbulk=getdefaultbytype(hdpk).bulk;
				let hdpm=(class<hdmagammo>)(pickuptype);
				if(hdpm){
					let hdpmdef=getdefaultbytype(hdpm);
					defunitbulk=max(defunitbulk,hdpmdef.magbulk+hdpmdef.roundbulk*hdpmdef.maxperunit);
				}
				int maxtake;
				defunitbulk*=hdmath.getencumbrancemult();
				if(!defunitbulk)maxtake=int.MAX;else maxtake=(HDCONST_BPMAX-bp.bulk)/defunitbulk;
				int increase=min(maxtake,amount);
				amount-=increase;
				bp.amounts[bpindex]=""..(bp.amounts[bpindex].toint()+increase);
				bp.updatemessage(bpindex);
				if(amount<1)destroy();
				else setstatelabel("spawn");
				return;
			}
		}

		//check effective maxamount and take as appropriate
		int maxtake=getdefaultbytype(pickuptype).maxamount;
		let hdpk=(class<hdpickup>)(pickuptype);
		let hdp=hdplayerpawn(picktarget);
		if(hdp&&hdpk){
			double defunitbulk=getdefaultbytype(hdpk).bulk;
			let hdpm=(class<hdmagammo>)(pickuptype);
			if(hdpm){
				let hdpmdef=getdefaultbytype(hdpm);
				defunitbulk=max(defunitbulk,hdpmdef.magbulk+hdpmdef.roundbulk*hdpmdef.maxperunit);
			}
			double divamt=defunitbulk*hdmath.getencumbrancemult();
			if(!divamt)maxtake=int.MAX;
			else maxtake=min(maxtake,
				(hdp.maxpocketspace-hdp.itemenc*hdmath.getencumbrancemult())
				/divamt
			);
		}
		int increase=amount;
		increase=min(maxtake,amount);
		if(heat.getamount(self)>50)increase=0;
		if(increase<1){ //didn't pick any up
			setstatelabel("spawn");
			return;
		}
		picktarget.A_PlaySound(pickupsound,5);
		picktarget.A_Log(string.format("\cg%s",pickupmessage),true);
		HDF.Give(picktarget,pickuptype,increase);
		amount-=increase;
		if(amount>0){ //only picked some up  
			setstatelabel("spawn");
			return;
		}else if(pickuptype!="none")destroy();
	}
	states{
	give:
		---- A 0;
		stop;
	spawn:
		CLIP A -1;
	spawn2:
		---- A -1;
	}
}





