#include	<multicolors>

#include	<tf2_stocks>
#include	<cstrike>

public	Extension	__ext_tf2	=	{
	name		=	"TF2 Tools",	//This allows any game to load without "TF2 Tools Extension is required" error on plugin startup
	file		=	"game.tf2.ext",	//since the other games doesn't use the tf2 natives and the extension is automatically loaded
	required	=	0				//when server is running team fortress 2
};

public	Extension	__ext_cstrike	=	{
	name		=	"cstrike",
	file		=	"games/game.cstrike.ext",
	required	=	0
};

#pragma		semicolon	1
#pragma		newdecls	required

#define		TAG			"[Respawn Manager] "	//If you wanna have your own tag

public	Plugin	myinfo	=	{
	name		=	"[ANY] Respawn Manager",
	author		=	"Tk /id/Teamkiller324",
	description	=	"Manages the respawns",
	version		=	"1.0.1",
	url			=	"https://steamcommunity.com/id/Teamkiller324"
}

ConVar	respawn_mgr,
		respawn_cmd,
		respawn_msg,
		respawn_vip,
		respawn_vip_flag,
		respawn_vip_enabled,
		respawn_admin,
		respawn_admin_flag,
		respawn_admin_enabled,
		respawn_owner,
		respawn_owner_flag,
		respawn_owner_enabled,
		respawn_tf2_red,
		respawn_tf2_blu,
		respawn_tf2_grn,
		respawn_tf2_ylw,
		respawn_cs_t,
		respawn_cs_ct;
		
//Get the flags
char	owner_flag_string[16],
		admin_flag_string[16],
		vip_flag_string[16];
	
int		owner_flag,
		admin_flag,
		vip_flag;

public	void	OnPluginStart()	{
	//Translations
	LoadTranslations("respawn_manager.phrases");
	LoadTranslations("common.phrases");
	
	//ConVars
	respawn_mgr		=	CreateConVar("sm_respawn_manager_enabled",	"1",	"Should respawn manager be enabled?",		FCVAR_NOTIFY,	true,	0.0,	true,	1.0);
	respawn_cmd		=	CreateConVar("sm_respawn_manager_cmd",		"1",	"Should respawn command be enabled?",		_,	true,	0.0,	true,	1.0);
	respawn_msg		=	CreateConVar("sm_respawn_manager_msg",		"0",	"Should respawn message be enabled?",		_,	true,	0.0,	true,	1.0);
	
	//Administration
	respawn_vip				=	CreateConVar("sm_respawn_manager_vip",				"5",	"Respawn time for VIP users",										_,	true,	0.0);
	respawn_vip_flag		=	CreateConVar("sm_respawn_manager_vip_flag",			"a",	"VIP Flag required for custom respawn time");
	respawn_vip_enabled		=	CreateConVar("sm_respawn_manager_vip_enabled",		"1",	"Disable VIP custom respawn time? \n1 = Enabled \n2 = Disabled",	_,	true,	0.0,	true,	1.0);
	respawn_admin			=	CreateConVar("sm_respawn_manager_admin",			"5",	"Respawn time for Admin users",										_,	true,	0.0);
	respawn_admin_flag		=	CreateConVar("sm_respawn_manager_admin_flag",		"b",	"Admin Flag required for custom respawn time");
	respawn_admin_enabled	=	CreateConVar("sm_respawn_manager_admin_enabled",	"1",	"Disable Admin custom respawn time? \n1 = Enabled \n2 = Disabled",	_,	true,	0.0,	true,	1.0);
	respawn_owner			=	CreateConVar("sm_respawn_manager_owner",			"5",	"Respawn time for the Owner",										_,	true,	0.0);
	respawn_owner_flag		=	CreateConVar("sm_respawn_manager_owner_flag",		"z",	"Owner Flag required for custom respawn time");
	respawn_owner_enabled	=	CreateConVar("sm_respawn_manager_owner_enabled",	"1",	"Disable Owner custom respawn time? \n1 = Enabled \n2 = Disabled");
	
	//Commands
	RegAdminCmd("sm_respawn",	RespawnCmd,	ADMFLAG_SLAY,	"Respawn a specific user");
	
	switch(GetEngineVersion())	{
		case	Engine_TF2:	{
			//>TF2  - Team Fortress 2
			respawn_tf2_red	=	CreateConVar("sm_respawn_manager_red",		"5",	"Respawn time for red team",	FCVAR_NOTIFY,	true,	0.0);
			respawn_tf2_blu	=	CreateConVar("sm_respawn_manager_blu",		"5",	"Respawn time for blue team",	FCVAR_NOTIFY,	true,	0.0);
			char	game[16];
			GetGameFolderName(game,	sizeof(game));
			if(StrEqual(game,	"tf2classic"))	{
				//>TF2C - Team Fortress 2 Classic
				respawn_tf2_grn	=	CreateConVar("sm_respawn_manager_grn",		"5",	"Respawn time for green team",	FCVAR_NOTIFY,	true,	0.0);
				respawn_tf2_ylw	=	CreateConVar("sm_respawn_manager_ylw",		"5",	"Respawn time for yellow team",	FCVAR_NOTIFY,	true,	0.0);
			}
		}
		case	Engine_CSS,Engine_CSGO:	{
			//>CSS  - Counter-Strike: Source
			//>CSGO - Counter-Strike: Global Offensive
			respawn_cs_t	=	CreateConVar("sm_respawn_manager_t",		"5",	"Respawn time for terrorist team",			FCVAR_NOTIFY,	true,	0.0);
			respawn_cs_ct	=	CreateConVar("sm_respawn_manager_ct",		"5",	"Respawn time for counter-terrorist team",	FCVAR_NOTIFY,	true,	0.0);
		}
	}
		
	//Events
	HookEvent("player_death",	Event_PlayerDeath,	EventHookMode_Pre);
	
	//Flags
	owner_flag	=	ReadFlagString(owner_flag_string),
	admin_flag	=	ReadFlagString(admin_flag_string),
	vip_flag	=	ReadFlagString(vip_flag_string);
	
	GetConVarString(respawn_owner_flag,	owner_flag_string,	sizeof(owner_flag_string));
	GetConVarString(respawn_admin_flag,	admin_flag_string,	sizeof(admin_flag_string));
	GetConVarString(respawn_vip_flag,	vip_flag_string,	sizeof(vip_flag_string));
	
	AutoExecConfig(true,	"respawn_manager");
}

//Events
Action	Event_PlayerDeath(Event event,	const char[] name,	bool dontBroadcast)	{
	int	client	=	GetClientOfUserId(event.GetInt("userid"));
		
	if(respawn_mgr.BoolValue)	{
		if(IsClientOwner(client) && respawn_owner_enabled.BoolValue)
			RespawnClientTimer(client,	GetConVarFloat(respawn_owner));
		else if(IsClientAdmin(client) && respawn_admin_enabled.BoolValue)
			RespawnClientTimer(client,	GetConVarFloat(respawn_admin));
		else if(IsClientVip(client) && respawn_vip_enabled.BoolValue)
			RespawnClientTimer(client,	GetConVarFloat(respawn_vip));
		else if(respawn_owner_enabled.BoolValue == false || respawn_admin_enabled.BoolValue == false || respawn_vip_enabled.BoolValue == false)	{
			if((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) == TF_DEATHFLAG_DEADRINGER)
				return Plugin_Continue;
			else	{
				switch(GetEngineVersion())	{
					case	Engine_TF2:	{
						switch(GetClientTeam(client))	{
							case	2:	RespawnClientTimer(client,	GetConVarFloat(respawn_tf2_red));
							case	3:	RespawnClientTimer(client,	GetConVarFloat(respawn_tf2_blu));
							case	4:	RespawnClientTimer(client,	GetConVarFloat(respawn_tf2_grn));
							case	5:	RespawnClientTimer(client,	GetConVarFloat(respawn_tf2_ylw));
						}
					}
					case	Engine_CSS,Engine_CSGO:	{
						switch(GetClientTeam(client))	{
							case	2:	RespawnClientTimer(client,	GetConVarFloat(respawn_cs_t));
							case	3:	RespawnClientTimer(client,	GetConVarFloat(respawn_cs_ct));
						}
					}
				}
			}
		}
	}
		
	return	Plugin_Continue;
}

void	RespawnClientTimer(int client,	float time)	{
	CreateTimer(time,	RespawnClient,	client);
	if(respawn_msg.BoolValue && time > 1)
		PrintHintText(client,	"%s",	"respawn_manager_message",	time);
}

Action	RespawnClient(Handle timer,	any client)	 {
	if(IsValidClient(client))	{
		switch(GetEngineVersion())	{
			case	Engine_TF2:	TF2_RespawnPlayer(client);
			case	Engine_CSS,Engine_CSGO: CS_RespawnPlayer(client);
		}
	}
}

//Commands
Action	RespawnCmd(int client,	int args)	{
	if(respawn_cmd.BoolValue)	{
		if(!IsValidClient(client))	{
			CReplyToCommand(client,	"%s %s",	TAG,	"respawn_manager_error");
			return	Plugin_Handled;
		}
		
		if(args != 1)	{
			CPrintToChat(client,	"%s %s",	TAG,	"respawn_manager_respawn_usage");
			return	Plugin_Handled;
		}
		
		char	arg1		[128],
				target_name	[MAX_TARGET_LENGTH];
		int		target_list[MAXPLAYERS],
				target_count;
		bool	tn_is_ml;
		GetCmdArg(1, arg1, sizeof(arg1));
		
		if((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			RespawnClientTimer(client,	0.2);
			CPrintToChat(client,	"%s %s",	TAG,	"respawn_manager_respawn",	target_name);
		}
	}
	return	Plugin_Handled;
}

//Checks the clients validity
stock	bool	IsClientOwner(int client)	{
	if(CheckCommandAccess(client,	"",	owner_flag,		false))	return	true;
	return	false;
}

stock	bool	IsClientModerator(int client)	{	//Unused atm
	if(CheckCommandAccess(client,	"",	ADMFLAG_CUSTOM1,	false))	return	true;
	return	false;
}

stock	bool	IsClientAdmin(int client)	{
	if(CheckCommandAccess(client,	"",	admin_flag,	false))	return	true;
	return	false;
}

stock	bool	IsClientVip(int client)	{
	if(CheckCommandAccess(client,	"",	vip_flag,	false))	return	true;
	return	false;
}

stock	bool	IsValidClient(int client)	{
	if(IsClientInGame(client))		return	true;
	if(!IsPlayerAlive(client))		return	true;
	if(client != 0)					return	true;
	return	false;
}