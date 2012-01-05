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
