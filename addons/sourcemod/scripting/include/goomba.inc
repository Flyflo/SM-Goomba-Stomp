#if defined _goomba_included_
  #endinput
#endif
#define _goomba_included_

public SharedPlugin:__pl_goomba =
{
	name = "goomba",
	file = "goomba.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_ircrelay_SetNTVOptional()
{
    MarkNativeAsOptional("GoombaStomp");
    MarkNativeAsOptional("CheckImmunity");
    MarkNativeAsOptional("PlayStompSound");
    MarkNativeAsOptional("PlayReboundSound");
    MarkNativeAsOptional("EmitReboundParticles");
}

/**
 * @brief Called right before the stomp
 *
 * @param attacker          Player doing the stomp
 * @param victim            Player being stomped
 * @param damageMultiplier  Damage multiplier based on the actual victim's life
 * @param damageBonus       Damage bonus
 * @return                  Plugin_Handled to block the stomp, Plugin_Changed to modify the damage
 */
forward Action:OnStomp(attacker, victim, &Float:damageMultiplier, &Float:damageBonus);

/**
 * @brief Stomp 
 *
 * @param attacker              Player doing the stomp
 * @param victim                Player being stomped
 * @param    damageMultiplier   Damage inflicted based on the victim's health (default: goomba_dmg_lifemultiplier)
 * @param    damageBonus        Damage bonus after damageMultiplier calculation (default: goomba_dmg_add)
 * @param    jumpPower          Jump power of the rebound (default: goomba_rebound_power)
 * @noreturn 
 */
native bool:GoombaStomp(attacker, victim, ...);

/**
 * @param attacker          Player doing the stomp
 * @param victim            Player being stomped
 * @return                  ImmunityResult based on the attacker and victim's immunity preferences
 */
native ImmunityResult:CheckImmunity(attacker, victim);

/**
 * @brief Play the stomped sound to the specified client
 *
 * @param client            Client to play the stomped sound to.
 * @noreturn
 */
native PlayStompSound(client);

/**
 * @brief Play the rebound sound from the specified client to everyone
 *
 * @param client            Player to play the rebound sound from.
 * @noreturn
 */
native PlayReboundSound(client);

/**
 * @brief Attach the rebound particles on the specified player
 *
 * @param client            Player to attach the particles on
 * @noreturn
 */
native EmitReboundParticles(client);

enum ImmunityResult
{
	NoImmunity = 0,
	AttackerImmunity,
	VictimImmunity,
};
