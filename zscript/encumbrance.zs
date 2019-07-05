// ------------------------------------------------------------
// Encumbrance
// ------------------------------------------------------------

//a battery should be about the size of your old flip phone but significantly heavier.
const ENC_BATTERY=18;
const ENC_BATTERY_LOADED=ENC_BATTERY*0.4;

//a ZM66 mag should be roughly the size of a battery.
//50 single rounds should inconvenience you far LESS than a single mag.
//https://www.youtube.com/watch?v=mjuEJjzon-g
const ENC_426MAG=16;
const ENC_426MAG_EMPTY=ENC_426MAG*0.4;
const ENC_426_LOADED=(ENC_426MAG*0.6)/50.;
const ENC_426=ENC_426_LOADED*1.4;
const ENC_426MAG_LOADED=ENC_426MAG_EMPTY*0.4;

const ENC_776MAG=42;
const ENC_776MAG_EMPTY=ENC_776MAG*0.5;
const ENC_776_LOADED=(ENC_776MAG*0.5)/30.;
const ENC_776=ENC_776_LOADED*1.8;
const ENC_776MAG_LOADED=ENC_776MAG_EMPTY*0.5;
const ENC_776B=ENC_776*0.3;
const ENC_776CLIP_EMPTY=ENC_776B;
const ENC_776CLIP=ENC_776CLIP_EMPTY+ENC_776*10;

const ENC_9MAG=10;
const ENC_9MAG_EMPTY=ENC_9MAG*0.3;
const ENC_9_LOADED=(ENC_9MAG*0.7)/15.;
const ENC_9=ENC_9_LOADED*1.4;
const ENC_9MAG_LOADED=ENC_9MAG_EMPTY*0.1; //it's almost entirely inside the handle!

const ENC_9MAG30_EMPTY=ENC_9MAG_EMPTY*2.4;
const ENC_9MAG30=ENC_9MAG30_EMPTY+ENC_9_LOADED*30;
const ENC_9MAG30_LOADED=ENC_9MAG30*0.9; //it's almost entirely outside!

const ENC_355=ENC_9*1.3;
const ENC_355_LOADED=ENC_9MAG_LOADED*1.3;


//other things
const ENC_SHELL=1.8;
const ENC_SHELLLOADED=0.6;
const ENC_ROCKET=ENC_426MAG*0.9;
const ENC_ROCKETLOADED=ENC_ROCKET*0.5;
const ENC_HEATROCKET=ENC_ROCKET*1.2;
const ENC_HEATROCKETLOADED=ENC_ROCKETLOADED*1.2;
const ENC_BRONTOSHELL=ENC_426MAG*0.4;
const ENC_BRONTOSHELLLOADED=ENC_BRONTOSHELL*0.4;
const ENC_FRAG=ENC_ROCKET*1.6;

//more things
const ENC_BLUEARMOUR=700;
const ENC_GREENARMOUR=360;
const ENC_RADSUIT=50;
const ENC_IEDKIT=3;
const ENC_SQUADSUMMONER=7;
const ENC_BLUEPOTION=12;
const ENC_LITEAMP=20;
const ENC_MEDIKIT=45;
const ENC_STIMPACK=7;
const ENC_LADDER=70;
const ENC_DERP=55;
const ENC_HERP=125;
const ENC_DOORBUSTER=ENC_HEATROCKET;


extend class HDPlayerPawn{
	double enc;
	double itemenc;
	double maxpocketspace;property maxpocketspace:maxpocketspace;
	double CheckEncumbrance(){
		if(!player)return 0;
		//separate counters for encumbrance evaluations other than penalty
		double weaponenc=0;
		double weaponencsel=0;
		itemenc=0;

		//add everything up
		double stacker=1.;
		for(inventory hdww=inv;hdww!=null;hdww=hdww.inv){
			let hdw=hdweapon(hdww);
			if(hdw&&!(hdw is "HDBackpack")){
				bool thisweapon=(
					hdw==player.readyweapon
					||(hdw==lastweapon&&nullweapon(player.readyweapon))
				);
				double gunbulk=hdw.weaponbulk();
				if(gunbulk>0){
					if(thisweapon)weaponencsel=gunbulk;
					else{
						weaponenc+=gunbulk;
						if(gunbulk>70){
							double stacked=(gunbulk-70)*0.0003;
							stacker+=stacked;
						}
					}
					//A_Log(string.format("%s  %.2f",hdw.getclassname(),gunbulk));
				}
			}else{
				let hdp=hdpickup(hdww);
				if(hdp)itemenc+=abs(hdp.getbulk());
			}
		}
		weaponenc*=stacker;

		//now add the spare weapons
		let spares=SpareWeapons(findinventory("SpareWeapons"));
		if(spares){
			double sparebulk;int sparesize;
			[sparebulk,sparesize]=spares.getwepbulk();
			if(sparesize>0){
				double avg=sparebulk*0.0003/sparesize;
				for(int i=0;i<sparesize;i++){
					stacker*=1.+avg;
				}
				weaponenc+=sparebulk*stacker;
			}
		}

		//add backpack
		double bpenc=0;
		let bp=hdbackpack(findinventory("HDBackpack"));
		if(bp)bpenc=bp.weaponbulk();

		//if sv_infiniteammo is on, give just enough to reload a gun once
		if(sv_infiniteammo){
			if(
				countinv("HDPistol")
				||countinv("DERPUsable")
			)A_SetInventory("HD9mMag15",2);
			if(
				countinv("HDSMG")
			)A_SetInventory("HD9mMag30",1);
			if(
				countinv("Hunter")
				||countinv("Slayer")
			)A_SetInventory("HDShellAmmo",12);
			if(
				countinv("ZM66AssaultRifle")
				||countinv("Vulcanette")
				||countinv("HERPUsable")
			)A_SetInventory("HD4mMag",5);
			if(
				countinv("Blooper")
				||countinv("HDRL")
				||countinv("ZM66AssaultRifle")
				||countinv("LiberatorRifle")
				||countinv("HDIEDKit")
			)A_SetInventory("HDRocketAmmo",6);
			if(
				countinv("Brontornis")
			)A_SetInventory("BrontornisRound",1);
			if(
				countinv("HDRL")
			)A_SetInventory("HEATAmmo",1);
			if(
				countinv("BossRifle")
			)A_SetInventory("HD7mClip",1);
			if(
				countinv("LiberatorRifle")
			)A_SetInventory("HD7mMag",1);
			A_SetInventory("HDFragGrenadeAmmo",1);
		}


		double carrymax=
			400+
			(zerk>0?100:0)+
			min(regenblues,150)+
			stimcount*2
		;
		enc=weaponenc+weaponencsel+itemenc+bpenc;

		//include encumbrance multiplier before outputting final
		return enc*hdmath.getencumbrancemult()/carrymax;
	}
}
