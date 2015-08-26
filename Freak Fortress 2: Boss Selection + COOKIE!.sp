#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <clientprefs>

/*
남겨진 것들: 언어 설정, 커맨드 한글화, 코드 최적화 (BossName을 삭제하는 방향으로..)

일단 전 이것에 대한 수정을 나중에 할 예정입니다. 여러분들이 건들여주세요!


*/

new String:Incoming[MAXPLAYERS+1][64];
new String:BossName[MAXPLAYERS+1][64];

new QueuePoint[MAXPLAYERS+1];

new bool:IsBossSelected[MAXPLAYERS+1];

new g_NextHale = -1;

new Handle:g_hBossCookie;


new Handle:g_NextHaleTimer = INVALID_HANDLE;

public Plugin:myinfo = {
	name = "Freak Fortress 2: Boss Selection + COOKIE!",
	description = "Allows players select their bosses by /ff2boss",
	author = "Tean Potry: Nopied◎",
};

public OnPluginStart()
{
	HookEvent("teamplay_round_win", event_round_end);
	RegConsoleCmd("ff2_boss", Command_SetMyBoss, "Set my boss");
	RegConsoleCmd("ff2boss", Command_SetMyBoss, "Set my boss");
	RegConsoleCmd("boss", Command_SetMyBoss, "Set my boss");
	
	g_hBossCookie  = RegClientCookie("BossCookie", " ", CookieAccess_Protected);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	LoadTranslations("ff2_boss_selection");
}

public Action:event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1; client<=MaxClients; client++)
	{
		new String:CookieV[50];
		GetClientCookie(client, g_hBossCookie, CookieV, 50);
		
		if(StrEqual(CookieV, "None"))
		{
			QueuePoint[client] = FF2_GetQueuePoints(client);
		}
	
	}
	
	CreateTimer(6.0, Timer_FindNone);
	
	return Plugin_Continue;

}

public Action:Timer_FindNone(Handle:hTimer)
{
	for(new client=1; client<=MaxClients; client++)
	{
		new String:CookieV[50];
		GetClientCookie(client, g_hBossCookie, CookieV, 50);
		
		if(StrEqual(CookieV, "None"))
		{
			FF2_SetQueuePoints(client, QueuePoint[client]);	
		}
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	new String:CookieV[50];
	
	IsBossSelected[client]=false;
	
	if(!AreClientCookiesCached(client)) 
	{
		IsBossSelected[client]=false;
		strcopy(Incoming[client], sizeof(Incoming[]), "");
		strcopy(BossName[client], sizeof(BossName[]), "랜덤");
		
		CookieV = "";
		
		SetClientCookie(client, g_hBossCookie, CookieV);
	}
	
	else 
	{
	GetClientCookie(client, g_hBossCookie, CookieV, 50);
		
	strcopy(Incoming[client], sizeof(Incoming[]), CookieV);
	strcopy(BossName[client], sizeof(BossName[]), CookieV);	
		
	}
	// 중요. 표시를 위한 것.
	// strcopy(Incoming[client], sizeof(Incoming[]), "");
}

public OnClientDisconnect(client)
{
	if (client == g_NextHale)
	{
		KillTimer(g_NextHaleTimer);
		Timer_FF2Panel1(INVALID_HANDLE);
	}
	// IsBossSelected[client]=false;


	// strcopy(Incoming[client], sizeof(Incoming[]), "");
}

public Action:Timer_FF2Panel1(Handle:hTimer)
{
	new maxclient=1;
	new maxpoints=FF2_GetQueuePoints(1);
	decl points;
	
	
	for(new client=2; client <= MaxClients; client++)
		if (FF2_GetBossIndex(client)==-1)
		{
			points = FF2_GetQueuePoints(client);
			if (points>maxpoints)
			{
				maxclient=client;
				maxpoints=points;
			}
		}
		
	if (CheckCommandAccess(maxclient, "ff2_boss", 0, true))
	{
		if(!IsBossSelected[maxclient])
		{
			g_NextHaleTimer = CreateTimer(20.0,Timer_FF2Panel2,maxclient, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action:Timer_FF2Panel2(Handle:hTimer,any:client)
{
	if(IsVoteInProgress())
	{
		g_NextHaleTimer = CreateTimer(5.0,Timer_FF2Panel2,client, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	Command_SetMyBoss(client,0);
	return Plugin_Continue;
}

public Action:Command_SetMyBoss(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "ff2boss_ingame_only");
		return Plugin_Handled;
	}
	
	if (!CheckCommandAccess(client, "ff2_boss", 0, true))
	{
		ReplyToCommand(client, "[SM] %t", "ff2boss_noaccess");
		return Plugin_Handled;
	}
	
	decl String:spclName[64];
	decl Handle:BossKV;
	
	if(args)
	{
		new String:bossName[64];
		GetCmdArgString(bossName, sizeof(bossName));
		for (new i = 0; (BossKV=FF2_GetSpecialKV(i,true)); i++)
		{
			if (KvGetNum(BossKV, "blocked",0)) continue;
			KvGetString(BossKV, "name", spclName, sizeof(spclName));

			if(StrContains(bossName, spclName, false)!=-1)
			{
				IsBossSelected[client]=true;
				strcopy(Incoming[client], sizeof(Incoming[]), spclName);
				
				CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossselected", spclName);
				return Plugin_Handled;
			}
			
			KvGetString(BossKV, "filename", spclName, sizeof(spclName));
			if(StrContains(bossName, spclName, false)!=-1)
			{
				IsBossSelected[client]=true;
				KvGetString(BossKV, "name", spclName, sizeof(spclName));
				strcopy(Incoming[client], sizeof(Incoming[]), spclName);
				
				CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossselected", spclName);
				return Plugin_Handled;
			}	
		}
		CReplyToCommand(client, "{olive}[FF2]{default} %t", "ff2boss_bossnotfound");
		return Plugin_Handled;
	}	
	
	new Handle:dMenu = CreateMenu(Command_SetMyBossH);
	SetMenuTitle(dMenu, "%t","ff2boss_title", BossName[client]);
	
	new String:s[256];
	Format(s, sizeof(s), "%t", "ff2boss_random_option");
	AddMenuItem(dMenu, "Random Boss", s);
	Format(s, sizeof(s), "%t", "ff2boss_none_1");
	AddMenuItem(dMenu, "None", s);
	
	
	for (new i = 0; (BossKV=FF2_GetSpecialKV(i,true)); i++)
	{
		if (KvGetNum(BossKV, "blocked",0)) continue;
		KvGetString(BossKV, "name", spclName, 64);
		AddMenuItem(dMenu,spclName,spclName);
		
	}
	SetMenuExitButton(dMenu, true);
	DisplayMenu(dMenu, client, 20);
	return Plugin_Handled;
}


public Command_SetMyBossH(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		
		case MenuAction_Select:
		{
			new String:CookieV[50];
			switch(param2)
			{
				case 0:
				{
					IsBossSelected[param1]=true;
					Incoming[param1] = "";
					BossName[param1] = "랜덤";
					
					CookieV = "";
					
					SetClientCookie(param1, g_hBossCookie, CookieV);
						
					CReplyToCommand(param1, "{olive}[FF2]{default} %t", "ff2boss_randomboss");
				}
				case 1:
				{
				
					IsBossSelected[param1]=true;
					Incoming[param1] = "";
					BossName[param1] = "보스 안함";
					
					CookieV = "None";
					
					SetClientCookie(param1, g_hBossCookie, CookieV);
					
					CReplyToCommand(param1, "{olive}[FF2]{default} %t", "ff2boss_none");
				
				}
				default:
				{
					IsBossSelected[param1]=true;
					GetMenuItem(menu, param2, Incoming[param1], sizeof(Incoming[]));
					
					strcopy(CookieV, sizeof(CookieV),Incoming[param1]);
					strcopy(BossName[param1], sizeof(BossName[]), Incoming[param1]);
					
					
					SetClientCookie(param1, g_hBossCookie, CookieV);
					
					CReplyToCommand(param1, "{olive}[FF2]{default} %t", "ff2boss_bossselected", Incoming[param1]);
				}
			}
		}
	}
}

public Action:FF2_OnSpecialSelected(boss, &SpecialNum, String:SpecialName[])
{
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if (!boss && !StrEqual(Incoming[client], ""))
	{
		IsBossSelected[client]=false;
		strcopy(SpecialName, sizeof(Incoming[]), Incoming[client]);
		// Incoming[client] = "";
		return Plugin_Changed;
	}
	return Plugin_Continue;
}