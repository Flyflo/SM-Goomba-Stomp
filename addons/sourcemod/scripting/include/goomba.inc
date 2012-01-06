#if defined _goomba_included_
  #endinput
#endif
#define _goomba_included_

public SharedPlugin:__pl_goomba =
{
	name = "goomba",
	file = "goomba.smx",
	required = 1,
};


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


native bool:GoombaStomp(attacker, victim, ...);

// Return true when the stomp can occurs
native ImmunityResult:CheckImmunity(attacker, victim);

native PlayStompSound(client);
native PlayReboundSound(client);

enum ImmunityResult
{
	NoImmunity = 0,
	AttackerImmunity,
	VictimImmunity,
};
