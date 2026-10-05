// specific doorway for items to be obtained by the player, so we can retrofit it to whatever system of items 
// we develop

function scr_item_reward(_x, _y, _type = undefined){
	var _id = scr_roll_item(_type);
	if (is_undefined(_id)) return false;
	var _p = instance_create_layer(_x, _y, "Instances", obj_pickup_item);
	_p.item_id = _id;
	_p.pickup_color = scr_rarity_color(global.item_db[$ _id].rarity);
	return true;
}