// ------------------------------------------------------------
// Stealth monster replacements
// ------------------------------------------------------------
class HDStealthPorter:Actor{
	class<actor>spawntype;
	property spawntype:spawntype;
	default{
		+ismonster
		maxtargetrange 512;
		speed 10;
		hdstealthporter.spawntype "";
		maxstepheight 128;
	}
	override void postbeginplay(){
		super.postbeginplay();
		if(!spawntype){
			A_SpawnItemEx("NinjaPirate",
				flags:SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS|SXF_TRANSFERAMBUSHFLAG
			);
			destroy();
			return;
		}
		A_SetSize(
			getdefaultbytype(spawntype).radius,
			getdefaultbytype(spawntype).height
		);
	}
	void A_CheckPortIn(){
		if(
			target
			&&absangle(target.angleto(self),target.angle)>90
		)setstatelabel("portin");
		else A_Wander();
	}
	void A_PortIn(){
		spawn("TeleFog",pos,ALLOW_REPLACE);
		A_SpawnItemEx(spawntype,
			flags:SXF_NOCHECKPOSITION|SXF_TRANSFERPOINTERS|SXF_TRANSFERAMBUSHFLAG
		);
		A_AlertMonsters();
	}
	states{
	spawn:
		TNT1 A 10 A_Look();
		loop;
	see:
		TNT1 A 4 A_Chase();
		loop;
	missile:
		TNT1 A 4 A_CheckPortIn();
		goto see;
	portin:
		TNT1 A 70 A_PlaySound(
			getdefaultbytype(spawntype).seesound,
			CHAN_VOICE,
			frandom(0.3,0.6),
			false,
			ATTN_NONE
		);
		TNT1 A 1 A_PortIn();
		stop;
	}
}
class HDStealthArachnotron:HDStealthPorter replaces StealthArachnotron{
	default{hdstealthporter.spawntype "Krangling";}
}
class HDStealthArchvile:HDStealthPorter replaces StealthArchvile{
	default{hdstealthporter.spawntype "ArchFiend";}
}
class HDStealthBaron:HDStealthPorter replaces StealthBaron{
	default{hdstealthporter.spawntype "HellPrince";}
}
class HDStealthCacodemon:HDStealthPorter replaces StealthCacodemon{
	default{
		+float
		hdstealthporter.spawntype "CaeloBite";
	}
}
class HDStealthChaingunGuy:HDStealthPorter replaces StealthChaingunGuy{
	default{hdstealthporter.spawntype "VulcanetteGuy";}
}
class HDStealthDemon:RandomSpawner replaces StealthDemon{
	default{
		+ismonster
		dropitem "NinjaPirate",256,20;
		dropitem "SpecBabuin",256,5;
		dropitem "ShellShade",256,1;
	}
}
class HDStealthHellKnight:HDStealthPorter replaces StealthHellKnight{
	default{hdstealthporter.spawntype "HellKnave";}
}
class HDStealthDoomImp:HDStealthPorter replaces StealthDoomImp{
	default{hdstealthporter.spawntype "FighterImp";}
}
class HDStealthMancubus:HDStealthPorter replaces StealthFatso{
	default{hdstealthporter.spawntype "Mancubus";}
}
class HDStealthBoner:HDStealthPorter replaces StealthRevenant{
	default{hdstealthporter.spawntype "Boner";}
}
class HDStealthRevenant:HDStealthBoner{}
class HDStealthShotgunGuy:HDStealthPorter replaces StealthShotgunGuy{
	default{hdstealthporter.spawntype "HideousShotgunGuy";}
}
class HDStealthZombieMan:HDStealthPorter replaces StealthZombieMan{
	default{hdstealthporter.spawntype "ZombieStormtrooper";}
}
