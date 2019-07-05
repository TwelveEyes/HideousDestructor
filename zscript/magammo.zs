// ------------------------------------------------------------
// Tracked magazines (and clips and batteries)
// ------------------------------------------------------------
class HDMagAmmo:HDAmmo{
	array<int> mags; //or clips or batteries, whatever
	int maxperunit;property maxperunit:maxperunit;
	class<inventory> roundtype;property roundtype:roundtype;
	double roundbulk;property roundbulk:roundbulk;
	double magbulk;property magbulk:magbulk;
	bool mustshowinmagmanager;property mustshowinmagmanager:mustshowinmagmanager;
	default{
		hdmagammo.maxperunit 0;
		hdmagammo.roundtype "";
		hdmagammo.roundbulk 0;
		hdmagammo.magbulk 0;
		hdmagammo.mustshowinmagmanager false;
	}
	override double getbulk(){
		double result=magbulk+roundbulk;
		if(!result)return bulk*amount;
		result=0;
		SyncAmount();
		for(int i=0;i<amount;i++){
			result+=magbulk+roundbulk*mags[i];
		}
		return result;
	}
	override int effectivemaxamount(){
		double unitbulk=max(bulk,(roundbulk*maxperunit*0.6)+magbulk);
		if(!unitbulk)return maxamount;
		double gdpsp;
		if(hdplayerpawn(owner))gdpsp=hdplayerpawn(owner).maxpocketspace;
		else gdpsp=getdefaultbytype("hdplayerpawn").maxpocketspace;
		return max(1,gdpsp/unitbulk);
	}

	//add mag amount or size as appropriate
	//should be called at the start of each interaction
	//should NEVER reduce the array to none if it was not none before
	virtual void SyncAmount(){
		amount=max(amount,mags.size());
		while(amount>mags.size()){
			//mags.push(random(1,maxperunit));	//testing
			mags.push(maxperunit);
		}
	}
	//remove one mag and return the value
	//use to load or drop
	int TakeMag(bool getmax){
		SyncAmount();
		if(amount<1)return -1;
		//the usual: get the last one
		if(!getmax){
			int lastmag=mags[mags.size()-1];
			mags.pop();
			amount=mags.size();
			return lastmag;
		}

		int maxindex=mags.find(maxperunit);
		//if fail, take the FIRST mag
		//(because last is probably what you just unloaded)
		if(
			maxindex==mags.size()
			&&mags[mags.size()-1]<maxperunit
		){
			int firstmag=mags[0];
			mags.delete(0);
			amount=mags.size();
			return firstmag;
		}
		//take one full mag
		mags.delete(maxindex);
		amount=mags.size();
		return maxperunit;
	}
	//take last mag and put it at index zero
	void LastToFirst(){
		SyncAmount();
		if(amount<2)return;
		mags.insert(0,mags[mags.size()-1]);
		mags.pop();
	}
	void FirstToLast(){
		SyncAmount();
		if(amount<2)return;
		mags.push(mags[0]);
		mags.delete(0);
	}
	//bring up the lowest-value mag
	//useful for refilling and discarding
	int LowestToLast(){
		SyncAmount();
		if(amount<2)return mags[0];
		int lowestindex=-1;
		int lowest=maxperunit;
		for(int i=0;i<amount;i++){
			if(lowest>mags[i]){
				lowest=mags[i];
				lowestindex=i;
			}
		}
		if(lowestindex<0)return maxperunit;
		mags.delete(lowestindex);
		mags.push(lowest);
		return lowest;
	}
	//bring up the highest-value non-full mag
	//useful for refilling and discarding
	void HighestFillableToLast(){
		SyncAmount();
		if(amount<2)return;
		int highestindex=-1;
		int highest=0;
		for(int i=0;i<amount;i++){
			if(highest>mags[i]&&mags[i]<maxperunit){
				highest=mags[i];
				highestindex=i;
			}
		}
		if(highestindex<0||highestindex==mags.size())return;
		mags.delete(highestindex);
		mags.push(highest);
	}
	//add a mag
	//use to unload
	virtual void AddAMag(int addamt=-1){
		SyncAmount();
		if(amount>=maxamount)return;
		if(addamt<0||addamt>maxperunit)addamt=maxperunit;
		mags.push(addamt);
		amount=mags.size();
	}
	//give a mag to someone
	static bool GiveMag(actor receiver,class<inventory> type,int giveamt){
		if(giveamt<0)return false;
		hdmagammo mmm;
		if(receiver.findinventory(type)){
			mmm=HDMagAmmo(receiver.findinventory(type));
			if(mmm.amount>=mmm.maxamount){
				HDMagAmmo.SpawnMag(receiver,type,giveamt);
				return false;
			}
			mmm.AddAMag(giveamt);
		}else{
			mmm=HDMagAmmo(receiver.GiveInventoryType(type));
			mmm.mags.clear();
			mmm.amount=0;
			mmm.AddAMag(giveamt);
		}

		if(
			receiver.player
			&&magmanager(receiver.player.readyweapon)
			&&(
				mmm.mustshowinmagmanager
				||mmm.roundtype!=""
			)
		){
			let mm=magmanager(receiver.player.readyweapon);
			mm.thismag=hdmagammo(receiver.findinventory(type));
			mm.updatetext();
		}
		return true;
	}
	//spawn and drop
	//mostly for unloads
	static actor SpawnMag(actor giver,class<inventory> type,int giveamt){
		if(giveamt<0)return null;
		let mmm=HDMagAmmo(giver.spawn(type,giver.pos,ALLOW_REPLACE));
		mmm.addz(giver.height-12);mmm.angle=giver.angle;
		mmm.A_ChangeVelocity(2,0,-1,CVF_RELATIVE);
		mmm.vel+=giver.vel;
		mmm.amount=0;
		mmm.mags.clear();
		mmm.AddAMag(giveamt);
		return mmm;
	}
	//for weapon reloading sequences so you don't look like an idiot
	//if(HDMagAmmo.NothingLoaded(self,"HD9mMag15"))
	static bool NothingLoaded(actor caller,class<inventory> magtype){
		let tocheck=HDMagAmmo(caller.findinventory(magtype));
		if(!tocheck)return true;
		tocheck.SyncAmount();
		for(int i=0;i<tocheck.amount;i++){
			if(tocheck.mags[i]>0)return false;
		}
		return true;
	}

	//add and extract rounds
	//return values can be used to stop loops or affect animations
	virtual bool Extract(){
		SyncAmount();
		if(
			mags.size()<1
			||mags[mags.size()-1]<1
			||owner.A_JumpIfInventory(roundtype,0,"null")
		)return false;
		HDF.Give(owner,roundtype,1);
		owner.A_PlaySound("weapons/rifleclick2",CHAN_WEAPON);
		mags[mags.size()-1]--;
		return true;
	}
	virtual bool Insert(){
		SyncAmount();
		if(
			mags.size()<1
			||mags[mags.size()-1]>=maxperunit
			||!owner.countinv(roundtype)
		)return false;
		owner.A_TakeInventory(roundtype,1,TIF_NOTAKEINFINITE);
		owner.A_PlaySound("weapons/rifleclick2",CHAN_WEAPON);
		mags[mags.size()-1]++;
		return true;
	}
	//consolidate
	override void Consolidate(){
		SyncAmount();
		if(amount<2)return;
		int totalrounds=0;
		for(int i=0;i<amount;i++){
			totalrounds+=mags[i];
			mags[i]=0; //keep the empties, do NOT call clear()!
		}
		for(int i=0;i<amount;i++){
			int toinsert=min(maxperunit,totalrounds);
			mags[i]=toinsert;
			totalrounds-=toinsert;
			if(totalrounds<1)break;
		}
	}
	//purge empty
	void PurgeEmpties(){
		SyncAmount();
		LowestToLast();
		while(mags[mags.size()-1]<1){
			owner.A_DropInventory(getclassname(),1);
			LowestToLast();
		}
	}
	//max everything
	virtual void MaxCheat(){
		mags.clear();
		for(int i=0;i<amount;i++){
			mags.push(maxperunit);
		}
	}

	//set sprite for mag manager: magsprite, roundsprite, roundtype, scale
	virtual clearscope string,string,name,double getmagsprite(int thismagamt){
		return "","","Clip",2.;
	}

	//debug: log amounts
	void LogAmounts(bool owneronly=false){
		string stt=string.format("%i  %s: ",amount,getclassname());
		for(int i=0;i<amount;i++){
			stt=string.format("%s %i",stt,mags[i]);
		}
		if(owneronly&&owner)owner.A_Log(stt,true);
		else A_Log(stt);
	}

	override void actualpickup(actor other){
		if(!other)other=picktarget;
		if(!other)return;
		name gcn=getclassname();

		//you're only ever picking up one at a time
		let alreadygot=HDMagAmmo(other.findinventory(gcn));
		if(alreadygot){
			alreadygot.syncamount();
			while(
				alreadygot.amount>=alreadygot.maxamount
				||(
					hdplayerpawn(picktarget)
					&&hdplayerpawn(picktarget).maxpocketspace-hdplayerpawn(picktarget).itemenc
						<(magbulk+roundbulk*mags[0])
				)
			){
				int thismag=mags[0];
				bool thisisbetter=false;
				for(int i=0;!thisisbetter&&i<alreadygot.amount;i++){
					if(thismag>alreadygot.mags[i])thisisbetter=true;
				}
				if(!thisisbetter)return;
				alreadygot.LowestToLast();
				if(hd_debug)alreadygot.logamounts();
				other.A_DropInventory(gcn,1);
			}
		}

		//misc. effects
		other.A_PlaySound(pickupsound,CHAN_AUTO);
		other.A_Log(string.format("\cg%s",pickupmessage()),true);

		//if no information, give max, otherwise use own array info
		if(mags.size()<1)other.A_GiveInventory(gcn);
		else HDMagAmmo.GiveMag(other,gcn,mags[0]);
		destroy();
	}
	override inventory createtossable(int amt){
		if(amount<1)return null;
		amt=min(max(1,amt),amount);
		inventory iii;
		for(int i=0;i<amt;i++){
			iii=inventory(spawn(getclassname(),owner.pos,ALLOW_REPLACE));
			if(iii){
				iii.amount=1;
				iii.addz(owner.height*0.6);
				iii.angle=owner.angle;iii.target=owner;iii.vel=owner.vel;
				iii.A_ChangeVelocity(4,frandom(-0.6,0.6),frandom(0.9,1.1),CVF_RELATIVE);
				if(bdroptranslation&&owner){
					actor onr=owner;
					if(iii)iii.translation=onr.translation;
				}
				let mmm=HDMagAmmo(iii);
				mmm.mags.clear();
				mmm.mags.push(takemag(false));
			}
		}
		return iii;
	}
	override void SplitPickup(){
		SyncAmount();
		while(amount>1){
			let aaa=HDMagAmmo(spawn(getclassname(),pos,ALLOW_REPLACE));
			aaa.amount=1;amount--;
			aaa.mags.clear();
			aaa.mags.push(takemag(false));
		}
		if(!mags[0]&&findstate("spawnempty"))setstatelabel("spawnempty");
		else if(findstate("spawn2")){
			if(hd_debug)A_Log(string.format("%s still uses spawn2",getclassname()));
			setstatelabel("spawn2");
		}
	}
	override void postbeginplay(){
		super.postbeginplay();
		syncamount();
	}

	states{
	use:
		TNT1 A 0{
			invoker.SyncAmount();
			A_SetInventory("MagManager",1);
			let mmm=MagManager(findinventory("MagManager"));
			mmm.thismag=invoker;mmm.thismagtype=invoker.getclassname();
			UseInventory(mmm);

			if(!invoker.amount||!hd_debug)return;

			invoker.LogAmounts(true);

			//stuff to test
			//give hdmagammo 10;wait 1;use hdmagammo
			//A_Log("PurgeEmpties");invoker.PurgeEmpties();
				//MaxCheat
				//LastToFirst
				//LowestToLast
				//HighestFillableToLast
				//Extract
				//Insert
				//Consolidate
				//TakeMag(true)
				//TakeMag(false)
				//SpawnMag
				//PurgeEmpties
			//invoker.LogAmounts();
		}fail;
	spawn:
		CELL A -1;
		stop;
	}
}
