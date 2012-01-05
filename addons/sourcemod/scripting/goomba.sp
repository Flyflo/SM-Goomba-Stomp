#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <colors>
#include <clientprefs>
#include <sdkhooks>

#define PL_NAME "Goomba Stomp"
#define PL_DESC "Goomba Stomp"
#define PL_VERSION "1.2.2#dev"

#define STOMP_SOUND "goomba/stomp.wav"
#define REBOUND_SOUND "goomba/rebound.wav"

public Plugin:myinfo =
{
    name = PL_NAME,
    author = "Flyflo",
    description = PL_DESC,
    version = PL_VERSION,
    url = "http://www.geek-gaming.fr"
}

new Handle:g_hForwardOnStomp;

new Handle:g_Cvar_StompMinSpeed = INVALID_HANDLE;
new Handle:g_Cvar_PluginEnabled = INVALID_HANDLE;
new Handle:g_Cvar_UberImun = INVALID_HANDLE;
new Handle:g_Cvar_JumpPower = INVALID_HANDLE;
new Handle:g_Cvar_CloakImun = INVALID_HANDLE;
new Handle:g_Cvar_StunImun = INVALID_HANDLE;
new Handle:g_Cvar_StompUndisguise = INVALID_HANDLE;
new Handle:g_Cvar_CloakedImun = INVALID_HANDLE;
new Handle:g_Cvar_BonkedImun = INVALID_HANDLE;
new Handle:g_Cvar_SoundsEnabled = INVALID_HANDLE;
new Handle:g_Cvar_ImmunityEnabled = INVALID_HANDLE;
new Handle:g_Cvar_DamageLifeMultiplier = INVALID_HANDLE;
new Handle:g_Cvar_DamageAdd = INVALID_HANDLE;

// Snippet from psychonic (http://forums.alliedmods.net/showpost.php?p=1294224&postcount=2)
new Handle:sv_tags;

new Handle:g_Cookie_ClientPref;

new Goomba_Fakekill[MAXPLAYERS+1];
new Goomba_SingleImmunityMessage[MAXPLAYERS+1];

// Thx to Pawn 3-pg
new bool:g_TeleportAtFrameEnd[MAXPLAYERS+1] = false;
new Float:g_TeleportAtFrameEnd_Vel[MAXPLAYERS+1][3];

public OnPluginStart()
{
    LoadTranslations("goomba.phrases");

    g_Cvar_PluginEnabled = CreateConVar("goomba_enabled", "1.0", "Plugin On/Off", 0, true, 0.0, true, 1.0);
    g_Cvar_StompMinSpeed = CreateConVar("goomba_minspeed", "360.0", "Minimum falling speed to kill", 0, true, 0.0, false, 0.0);
    g_Cvar_CloakImun = CreateConVar("goomba_cloak_immun", "1.0", "Prevent cloaked spies from stomping", 0, true, 0.0, true, 1.0);
    g_Cvar_StunImun = CreateConVar("goomba_stun_immun", "1.0", "Prevent stunned players from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_UberImun = CreateConVar("goomba_uber_immun", "1.0", "Prevent ubercharged players from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_JumpPower = CreateConVar("goomba_rebound_power", "300.0", "Goomba jump power", 0, true, 0.0);
    g_Cvar_StompUndisguise = CreateConVar("goomba_undisguise", "1.0", "Undisguise spies after stomping", 0, true, 0.0, true, 1.0);
    g_Cvar_CloakedImun = CreateConVar("goomba_cloaked_immun", "0.0", "Prevent cloaked spies from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_BonkedImun = CreateConVar("goomba_bonked_immun", "1.0", "Prevent bonked scout from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_SoundsEnabled = CreateConVar("goomba_sounds", "1", "Enable or disable sounds of the plugin", 0, true, 0.0, true, 1.0);
    g_Cvar_ImmunityEnabled = CreateConVar("goomba_immunity", "1", "Enable or disable the immunity system", 0, true, 0.0, true, 1.0);

    g_Cvar_DamageLifeMultiplier = CreateConVar("goomba_dmg_lifemultiplier", "1.0", "How much damage the victim will receive based on its actual life", 0, true, 0.0, false, 0.0);
    g_Cvar_DamageAdd = CreateConVar("goomba_dmg_add", "50.0", "Add this amount of damage after goomba_dmg_lifemultiplier calculation", 0, true, 0.0, false, 0.0);

    AutoExecConfig(true, "goomba");

    CreateConVar("goomba_version", PL_VERSION, PL_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    g_Cookie_ClientPref = RegClientCookie("goomba_client_pref", "", CookieAccess_Private);
    RegConsoleCmd("goomba_toggle", Cmd_GoombaToggle, "Toggle the goomba immunity client's pref.");
    RegConsoleCmd("goomba_status", Cmd_GoombaStatus, "Give the current goomba immunity setting.");
    RegConsoleCmd("goomba_on", Cmd_GoombaOn, "Enable stomp.");
    RegConsoleCmd("goomba_off", Cmd_GoombaOff, "Disable stomp.");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn);

    g_hForwardOnStomp = CreateGlobalForward("OnStomp", ET_Event, Param_Cell, Param_Cell, Param_FloatByRef, Param_FloatByRef);

    // sv_tags stuff
    sv_tags = FindConVar("sv_tags");
    MyAddServerTag("stomp");
    HookConVarChange(g_Cvar_PluginEnabled, OnPluginChangeState);

    // Support for plugin late loading
    for (new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            OnClientPutInServer(client);
        }
    }
}

public OnPluginEnd()
{
    MyRemoveServerTag("stomp");
}

public OnMapStart()
{
    PrecacheSound(STOMP_SOUND, true);
    PrecacheSound(REBOUND_SOUND, true);

    decl String:stompSoundServerPath[128];
    decl String:reboundSoundServerPath[128];
    Format(stompSoundServerPath, sizeof(stompSoundServerPath), "sound/%s", STOMP_SOUND);
    Format(reboundSoundServerPath, sizeof(reboundSoundServerPath), "sound/%s", REBOUND_SOUND);

    AddFileToDownloadsTable(stompSoundServerPath);
    AddFileToDownloadsTable(reboundSoundServerPath);
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_StartTouch, OnStartTouch);
    SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
}

public Action:OnStomp(attacker, victim, &Float:damageMultiplier, &Float:damageBonus)
{
    decl Action:result;

    Call_StartForward(g_hForwardOnStomp);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushFloatRef(damageMultiplier);
    Call_PushFloatRef(damageBonus);
    Call_Finish(result);

    return result;
}

public OnPluginChangeState(Handle:cvar, const String:oldVal[], const String:newVal[])
{
    if(GetConVarBool(g_Cvar_PluginEnabled))
    {
        MyAddServerTag("stomp");
    }
    else
    {
        MyRemoveServerTag("stomp");
    }
}

public Action:OnStartTouch(client, other)
{
    if(GetConVarBool(g_Cvar_PluginEnabled))
    {
        if(other > 0 && other <= MaxClients)
        {
            if(IsClientInGame(client) && IsPlayerAlive(client))
            {
                decl Float:ClientPos[3];
                decl Float:VictimPos[3];
                GetClientAbsOrigin(client, ClientPos);
                GetClientAbsOrigin(other, VictimPos);

                new Float:HeightDiff = ClientPos[2] - VictimPos[2];

                if((HeightDiff > 82.0) || ((GetClientButtons(other) & IN_DUCK) && (HeightDiff > 62.0)))
                {
                    decl Float:vec[3];
                    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vec);

                    if(vec[2] < GetConVarFloat(g_Cvar_StompMinSpeed) * -1.0)
                    {
                        if(GoombaCheck(client, other))
                        {
                            GoombaStomp(client, other);
                        }
                    }
                }
            }
        }
    }

    return Plugin_Continue;
}

bool:GoombaCheck(client, victim)
{
    if(victim <= 0 || victim > MaxClients)
    {
        return false;
    }

    decl String:edictName[32];
    GetEdictClassname(victim, edictName, sizeof(edictName));

    if(!StrEqual(edictName, "player"))
    {
        return false;
    }
    if(!IsPlayerAlive(victim))
    {
        return false;
    }
    if(GetClientTeam(client) == GetClientTeam(victim))
    {
        return false;
    }
    if(GetEntProp(victim, Prop_Data, "m_takedamage", 1) == 0)
    {
        return false;
    }

    if(GetConVarBool(g_Cvar_ImmunityEnabled))
    {
        decl String:strCookieClient[16];
        GetClientCookie(client, g_Cookie_ClientPref, strCookieClient, sizeof(strCookieClient));

        decl String:strCookieVictim[16];
        GetClientCookie(victim, g_Cookie_ClientPref, strCookieVictim, sizeof(strCookieVictim));

        if(StrEqual(strCookieClient, "on") || StrEqual(strCookieClient, "next_off"))
        {
            return false;
        }
        else
        {
            if(StrEqual(strCookieVictim, "on") || StrEqual(strCookieVictim, "next_off"))
            {
                if(Goomba_SingleImmunityMessage[client] == 0)
                {
                    CPrintToChat(client, "%t", "Victim Immun");
                }

                Goomba_SingleImmunityMessage[client] = 1;
                CreateTimer(0.5, InhibMessage, client);
                return false;
            }
        }
    }

    if((GetConVarBool(g_Cvar_UberImun) && TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_StunImun) && TF2_IsPlayerInCondition(victim, TFCond_Dazed))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_CloakImun) && TF2_IsPlayerInCondition(client, TFCond_Cloaked))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_CloakedImun) && TF2_IsPlayerInCondition(victim, TFCond_Cloaked))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_BonkedImun) && TF2_IsPlayerInCondition(victim, TFCond_Bonked))
    {
        return false;
    }

    return true;
}

GoombaStomp(client, victim)
{
    new Float:damageMultiplier = GetConVarFloat(g_Cvar_DamageLifeMultiplier);
    new Float:damageBonus = GetConVarFloat(g_Cvar_DamageAdd);

    new Action:stompForwardResult = OnStomp(client, victim, damageMultiplier, damageBonus);

    if(stompForwardResult == Plugin_Continue)
    {
        damageMultiplier = GetConVarFloat(g_Cvar_DamageLifeMultiplier);
        damageBonus = GetConVarFloat(g_Cvar_DamageAdd);
    }
    else if(stompForwardResult != Plugin_Changed)
    {
        return;
    }

    new particle = AttachParticle(victim, "mini_fireworks");
    if(particle != -1)
    {
        CreateTimer(5.0, Timer_DeleteParticle, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
    }

    new victim_health = GetClientHealth(victim);

    // Rebond
    decl Float:vecAng[3], Float:vecVel[3];
    GetClientEyeAngles(client, vecAng);
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecVel);
    vecAng[0] = DegToRad(vecAng[0]);
    vecAng[1] = DegToRad(vecAng[1]);
    vecVel[0] = GetConVarFloat(g_Cvar_JumpPower) * Cosine(vecAng[0]) * Cosine(vecAng[1]);
    vecVel[1] = GetConVarFloat(g_Cvar_JumpPower) * Cosine(vecAng[0]) * Sine(vecAng[1]);
    vecVel[2] = GetConVarFloat(g_Cvar_JumpPower) + 100.0;

    g_TeleportAtFrameEnd[client] = true;
    g_TeleportAtFrameEnd_Vel[client] = vecVel;

    Goomba_Fakekill[victim] = 1;
    SDKHooks_TakeDamage(victim,
                        client,
                        client,
                        victim_health * damageMultiplier + damageBonus,
                        DMG_PREVENT_PHYSICS_FORCE | DMG_CRUSH | DMG_ALWAYSGIB);

    // The victim is übercharged
    if(TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
    {
        ForcePlayerSuicide(victim);
    }
    Goomba_Fakekill[victim] = 0;
}

public OnPreThinkPost(client)
{
    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        if(g_TeleportAtFrameEnd[client])
        {
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, g_TeleportAtFrameEnd_Vel[client]);

            if(GetConVarBool(g_Cvar_SoundsEnabled))
            {
                EmitSoundToAll(REBOUND_SOUND, client);
            }
        }
    }
    g_TeleportAtFrameEnd[client] = false;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));

    if(Goomba_Fakekill[victim] == 1)
    {
        new killer = GetClientOfUserId(GetEventInt(event, "attacker"));

        new damageBits = GetEventInt(event, "damagebits");

        SetEventString(event, "weapon_logclassname", "goomba");
        SetEventString(event, "weapon", "taunt_scout");
        SetEventInt(event, "damagebits", damageBits |= DMG_ACID);
        SetEventInt(event, "customkill", 0);
        SetEventInt(event, "playerpenetratecount", 0);

        if(!(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
        {
            if(GetConVarBool(g_Cvar_SoundsEnabled))
            {
                EmitSoundToClient(victim, STOMP_SOUND, victim);
            }

            PrintHintText(victim, "%t", "Victim Stomped");
        }

        if(GetConVarBool(g_Cvar_StompUndisguise))
        {
            TF2_RemovePlayerDisguise(killer);
        }

        CPrintToChatAllEx(killer, "%t", "Goomba Stomp", killer, victim);
    }

    return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    decl String:strCookie[16];
    GetClientCookie(client, g_Cookie_ClientPref, strCookie, sizeof(strCookie));

    //-----------------------------------------------------
    // on       = Immunity enabled
    // off      = Immunity disabled
    // next_on  = Immunity enabled on respawn
    // next_off = Immunity disabled on respawn
    //-----------------------------------------------------

    if(StrEqual(strCookie, ""))
    {
        SetClientCookie(client, g_Cookie_ClientPref, "off");
    }
    else if(StrEqual(strCookie, "next_off"))
    {
        SetClientCookie(client, g_Cookie_ClientPref, "off");
    }
    else if(StrEqual(strCookie, "next_on"))
    {
        SetClientCookie(client, g_Cookie_ClientPref, "on");
    }
}

public Action:Cmd_GoombaToggle(client, args)
{
    if(GetConVarBool(g_Cvar_ImmunityEnabled))
    {
        decl String:strCookie[16];
        GetClientCookie(client, g_Cookie_ClientPref, strCookie, sizeof(strCookie));

        if(StrEqual(strCookie, "off") || StrEqual(strCookie, "next_off"))
        {
            SetClientCookie(client, g_Cookie_ClientPref, "next_on");
            ReplyToCommand(client, "%t", "Immun On");
        }
        else
        {
            SetClientCookie(client, g_Cookie_ClientPref, "next_off");
            ReplyToCommand(client, "%t", "Immun Off");
        }
    }
    else
    {
        ReplyToCommand(client, "%t", "Immun Disabled");
    }
    return Plugin_Handled;
}

public Action:Cmd_GoombaOn(client, args)
{
    if(GetConVarBool(g_Cvar_ImmunityEnabled))
    {
        decl String:strCookie[16];
        GetClientCookie(client, g_Cookie_ClientPref, strCookie, sizeof(strCookie));

        if(!StrEqual(strCookie, "off"))
        {
            SetClientCookie(client, g_Cookie_ClientPref, "next_off");
            ReplyToCommand(client, "%t", "Immun Off");
        }
    }
    else
    {
        ReplyToCommand(client, "%t", "Immun Disabled");
    }
    return Plugin_Handled;
}

public Action:Cmd_GoombaOff(client, args)
{
    if(GetConVarBool(g_Cvar_ImmunityEnabled))
    {
        decl String:strCookie[16];
        GetClientCookie(client, g_Cookie_ClientPref, strCookie, sizeof(strCookie));

        if(!StrEqual(strCookie, "on"))
        {
            SetClientCookie(client, g_Cookie_ClientPref, "next_on");
            ReplyToCommand(client, "%t", "Immun On");
        }
    }
    else
    {
        ReplyToCommand(client, "%t", "Immun Disabled");
    }
    return Plugin_Handled;
}

public Action:Cmd_GoombaStatus(client, args)
{
    if(GetConVarBool(g_Cvar_ImmunityEnabled))
    {
        decl String:strCookie[16];
        GetClientCookie(client, g_Cookie_ClientPref, strCookie, sizeof(strCookie));

        if(StrEqual(strCookie, "on"))
        {
            ReplyToCommand(client, "%t", "Status Off");
        }
        if(StrEqual(strCookie, "off"))
        {
            ReplyToCommand(client, "%t", "Status On");
        }
        if(StrEqual(strCookie, "next_off"))
        {
            ReplyToCommand(client, "%t", "Status Next On");
        }
        if(StrEqual(strCookie, "next_on"))
        {
            ReplyToCommand(client, "%t", "Status Next Off");
        }
    }
    else
    {
        ReplyToCommand(client, "%t", "Immun Disabled");
    }

    return Plugin_Handled;
}

public Action:InhibMessage(Handle:timer, any:client)
{
    Goomba_SingleImmunityMessage[client] = 0;
}

public Action:Timer_DeleteParticle(Handle:timer, any:ref)
{
    new particle = EntRefToEntIndex(ref);
    DeleteParticle(particle);
}

stock AttachParticle(entity, String:particleType[])
{
    new particle = CreateEntityByName("info_particle_system");
    decl String:tName[128];

    if(IsValidEdict(particle))
    {
        decl Float:pos[3] ;
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
        pos[2] += 74;
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

        Format(tName, sizeof(tName), "target%i", entity);

        DispatchKeyValue(entity, "targetname", tName);
        DispatchKeyValue(particle, "targetname", "tf2particle");
        DispatchKeyValue(particle, "parentname", tName);
        DispatchKeyValue(particle, "effect_name", particleType);
        DispatchSpawn(particle);

        SetVariantString(tName);
        SetVariantString("flag");
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");

        return particle;
    }
    return -1;
}

stock DeleteParticle(any:particle)
{
    if (particle > MaxClients && IsValidEntity(particle))
    {
        decl String:classname[256];
        GetEdictClassname(particle, classname, sizeof(classname));

        if (StrEqual(classname, "info_particle_system", false))
        {
            AcceptEntityInput(particle, "Kill");
        }
    }
}

stock MyAddServerTag(const String:tag[])
{
    decl String:currtags[128];
    if (sv_tags == INVALID_HANDLE)
    {
        return;
    }

    GetConVarString(sv_tags, currtags, sizeof(currtags));
    if (StrContains(currtags, tag) > -1)
    {
        // already have tag
        return;
    }

    decl String:newtags[128];
    Format(newtags, sizeof(newtags), "%s%s%s", currtags, (currtags[0]!=0)?",":"", tag);
    new flags = GetConVarFlags(sv_tags);
    SetConVarFlags(sv_tags, flags & ~FCVAR_NOTIFY);
    SetConVarString(sv_tags, newtags);
    SetConVarFlags(sv_tags, flags);
}

stock MyRemoveServerTag(const String:tag[])
{
    decl String:newtags[128];
    if (sv_tags == INVALID_HANDLE)
    {
        return;
    }

    GetConVarString(sv_tags, newtags, sizeof(newtags));
    if (StrContains(newtags, tag) == -1)
    {
        // tag isn't on here, just bug out
        return;
    }

    ReplaceString(newtags, sizeof(newtags), tag, "");
    ReplaceString(newtags, sizeof(newtags), ",,", "");
    new flags = GetConVarFlags(sv_tags);
    SetConVarFlags(sv_tags, flags & ~FCVAR_NOTIFY);
    SetConVarString(sv_tags, newtags);
    SetConVarFlags(sv_tags, flags);
}
