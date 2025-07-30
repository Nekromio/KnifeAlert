#pragma semicolon 1
#pragma newdecls required

#include <sdktools_sound>
#include <sdktools_stringtables>
#include <clientprefs>

ConVar
	cvEnable;

Menu
	hMenu[2][MAXPLAYERS+1];

Handle
	hCookie[2];

ArrayList
	hSoundList;

enum struct Volume
{
	bool enable;
	float volume;
}

Volume data[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Knife Alert",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Оповещение от убийства с ножа",
	version = "1.0.1",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	hSoundList = new ArrayList(ByteCountToCells(256));
	
	hCookie[0] = RegClientCookie("KnifeAlertEnable", "cookies for a Enable knife sound", CookieAccess_Public);
	hCookie[1] = RegClientCookie("KnifeAlertVol", "cookies for a Vol knife sound", CookieAccess_Public);
	
	cvEnable = CreateConVar("sm_knife_enable", "1", "Включить/выключить плагин", _, true, _, true, 1.0);
	
	HookEvent("player_death", Event_PlayerDeath);
	
	RegConsoleCmd("sm_ks", Cmd_Menu);
	
	AutoExecConfig(true, "knife_alert");
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
		return;

	getEnableSound(client);
	getVolume(client);
}

public void OnClientDisconnect(int client)
{
	setCookie(client);
}

Action Cmd_Menu(int client, any argc)
{
	if(!client || IsFakeClient(client))
		return Plugin_Continue;
	
	CreateMenuEnable(client);
	hMenu[0][client].Display(client, 30);
	
	return Plugin_Handled; 
}

public void OnMapStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/knife_alert.ini");

	Handle hFile = OpenFile(sPath, "r");

	if (hFile == null)
	{
		ThrowError("Файл [%s] не существует!", sPath);
	}

	hSoundList.Clear();

	while (!IsEndOfFile(hFile))
	{
		if (!ReadFileLine(hFile, sPath, sizeof(sPath)))
		{
			continue;
		}

		RemoveComments(sPath);

		TrimString(sPath);
		if (sPath[0] == '\0')
		{
			continue;
		}

		char sBuffer[512];
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sPath);
		AddFileToDownloadsTable(sBuffer);
		PrecacheSound(sPath, true);
		hSoundList.PushString(sPath);
	}
	
	hFile.Close();
}

void RemoveComments(char[] line)
{
	static const char COMMENT_CHARS[] = "//#;";
	for (int i = 0; i < sizeof(COMMENT_CHARS) - 1; i++)
	{
		int index = StrContains(line, COMMENT_CHARS[i]);
		if (index != -1)
		{
			line[index] = '\0';
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(!cvEnable.BoolValue)
		return;

	char sWeapon[24];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));

	if(!strcmp(sWeapon, "knife") || (StrContains(sWeapon, "bayonet", false) != -1))
	{
		int victim = GetClientOfUserId(event.GetInt("userid"));
		int killer = GetClientOfUserId(event.GetInt("attacker"));
		
		if(victim && killer && GetClientTeam(victim) != GetClientTeam(killer))
		{
			PrintToChatAll("\x04===================================");
			PrintToChatAll("\x03[\x04S\x03M\x04] \x03%N \x04 убил с Ножа \x03 %N", killer, victim);
			PrintToChatAll("\x04===================================\n");

			if(!GetArraySize(hSoundList))
				return;

			char sSound[PLATFORM_MAX_PATH];
			int rnd = GetRandomInt(0, GetArraySize(hSoundList) - 1);
			hSoundList.GetString(rnd, sSound, sizeof(sSound));

			for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && data[i].enable == true)
			{
				EmitSoundToClient(i, sSound, i, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, data[i].volume);
			}
		}
	}
}

void CreateMenuEnable(int client)
{
	hMenu[0][client] = new Menu(VoiceMenu);
	hMenu[0][client].SetTitle("Меню KnifeAlert");

	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%s", data[client].enable ? "Звук включен [√]" : "Звук отключен[x]");
	hMenu[0][client].AddItem("item1", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "Изменить громкость %d [♫]", FloatToPercent(data[client].volume));
	hMenu[0][client].AddItem("item2", sBuffer);
}

public int VoiceMenu(Menu hMenuLocal, MenuAction action, int client, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenuLocal;
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 0: CheckCookie(client, Refund(client));
				case 1: 
				{
					CreateMenuVal(client);
					hMenu[1][client].Display(client, 25);
				}
			}
		}
	}
	return 0;
}

void CheckCookie(int client, bool enable)
{
	data[client].enable = enable;
	PrintToChat(client, "Звук KnifeAlert %s !", enable ? "включен" : "отключен");
	char sBuffer[4];
	Format(sBuffer, sizeof(sBuffer), "%d", enable);
	SetClientCookie(client, hCookie[0], sBuffer);
}

bool Refund(int client)
{
	return data[client].volume ? false : true;
}

void CreateMenuVal(int client)
{
	hMenu[1][client] = new Menu(ValMenu);
	hMenu[1][client].SetTitle("Меню громкости KnifeAlert");

	int volumes[] = {100, 80, 60, 40, 20, 0};

	for (int i = 0; i < sizeof(volumes); i++)
	{
		char buffer[32];
		Format(buffer, sizeof(buffer), "Громкость %d [♫]", volumes[i]);
		hMenu[1][client].AddItem(buffer, buffer);
	}
}

public int ValMenu(Menu hMenuLocal, MenuAction action, int client, int iItem)
{
	switch(action)
	{
		case MenuAction_End: delete hMenuLocal;
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 0: SetVolume(client, 1.0);
				case 1: SetVolume(client, 0.8);
				case 2: SetVolume(client, 0.6);
				case 3: SetVolume(client, 0.4);
				case 4: SetVolume(client, 0.2);
				case 5: SetVolume(client, 0.0);
			}
		}
	}
	return 0;
}

void SetVolume(int client, float volume)
{
	data[client].volume = volume;
	PrintToChat(client, "Вы выбрали громкость в [%.1f%]", volume);
	char sBuffer[4];
	Format(sBuffer, sizeof(sBuffer), "%.1f", volume);
	SetClientCookie(client, hCookie[1], sBuffer);
}

int FloatToPercent(float value)
{
	return RoundToZero(value * 100.0);
}

void getEnableSound(int client)
{
	char sBuffer[4];
	GetClientCookie(client, hCookie[0], sBuffer, sizeof(sBuffer));
	if(sBuffer[0])
		data[client].enable = view_as<bool>(StringToInt(sBuffer));
	else data[client].enable = true;
}

void getVolume(int client)
{
	char sBuffer[4];
	GetClientCookie(client, hCookie[1], sBuffer, sizeof(sBuffer));
	if(sBuffer[0])
		data[client].volume = view_as<float>(StringToFloat(sBuffer));
	else data[client].volume = 1.0;
}

void setCookie(int client)
{
	char sBuffer[4];
	Format(sBuffer, sizeof(sBuffer), "%.1f", data[client].volume);
	SetClientCookie(client, hCookie[1], sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%d", data[client].enable);
	SetClientCookie(client, hCookie[0], sBuffer);
}