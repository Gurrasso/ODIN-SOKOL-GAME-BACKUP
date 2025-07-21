package game


import "core:log"
import "core:math"
import "core:math/linalg"
import sapp "../../sokol/app"
import sg "../../sokol/gfx"
import "../utils"
import "../draw"
import cu "../utils/color"
import es "../enteties"
import "../events"
import "../utils/cooldown"


//COMPONENTS

Item_data :: struct{
	img: sg.Image,
	size: Vec2,
}

init_item :: proc(transform: ^Transform, item_data: Item_data) -> Sprite_id{
	transform.size = item_data.size
	return draw.init_sprite(item_data.img, transform^, "", draw_priority = .item)
}

update_item :: proc(transform: Transform, item_data: Item_data, sprite_id: string){
	draw.update_sprite(img = item_data.img, transform = transform, id = sprite_id)
}

//projectile weapon
Projectile_weapon :: struct{
	//id of the cooldown object that is linked to this weapon
	cooldown_object: cooldown.Cooldown,
	//cooldown of the weapon
	cooldown: f32,
	//shoot button
	trigger: sapp.Mousebutton,
	//a radian value that uses the add_randomness_vec2 function to add some randomness to the projectile directions
	random_spread: f32,
	//how far apart shots will be also in radians
	spread: f32,
	//number of shots the weapon fires
	shots: int,
	//add some camera shake to the shot
	camera_shake: f32,
	//the default values of the projectiles
	projectile: Projectile,
	
	automatic: bool,
}

//init function that runs when the item holder inits with a projectile weapon or when a projectile weapon is given to an item holder
init_projectile_weapon :: proc(weapon: ^Projectile_weapon){	
	weapon.cooldown_object = cooldown.init_cooldown_object(weapon.cooldown)	
}

reset_projectile_weapon :: proc(projectiles: ^Projectile_weapon){
	
}

//update function runs that runs every frame inside of item holder ( only if the item is equiped ofc )
update_projectile_weapon :: proc(weapon: ^Projectile_weapon, shoot_dir: Vec2, shoot_pos: Vec2){
	//add a projectile to the array if you press the right trigger
	should_shoot: bool
	
	if cooldown.cooldown_enabled(weapon.cooldown_object) do should_shoot = false
	else if !weapon.automatic do should_shoot = events.listen_mouse_single_down(weapon.trigger)
	else do should_shoot = events.listen_mouse_down(weapon.trigger)

	if should_shoot{
		cooldown.start_cooldown(weapon.cooldown_object)
		for i in 0..< weapon.shots{
						
			sprite_id := utils.generate_string_id()
		
			//offset position of shots if we shoot multiple
			shoot_dir := shoot_dir
			if weapon.shots > 1{
				offset := (f32(i)-math.floor(f32(weapon.shots/2)))	* weapon.spread
				shoot_dir = utils.offset_vec2(shoot_dir, offset)
			}

			init_projectile(weapon.projectile, shoot_pos, utils.add_randomness_vec2(shoot_dir, weapon.random_spread), sprite_id)
		}
			
		draw.shake_camera(weapon.camera_shake)
	}
}

//projectile
Projectile :: struct{
	img: sg.Image,
	lifetime: f32,
	speed: f32,
	damage: f32,
	
	transform: Transform,	
	sprite_id: string,
	duration: f32,
	dir: Vec2,
}

update_projectiles :: proc(projectiles: ^[dynamic]Projectile){
	//update the projectiles and check if they should be removed	
	for i := 0; i < len(projectiles); i+=1{
		update_projectile(&projectiles[i])

		if projectiles[i].duration > projectiles[i].lifetime{
			remove_projectile(&projectiles[i])
			ordered_remove(projectiles, i)
			i-=1
		}
	}
}

//update the projectile
update_projectile :: proc(projectile: ^Projectile){
	projectile.duration += utils.dt
	projectile.transform.pos += projectile.dir * projectile.speed * utils.dt
	draw.update_sprite(transform = projectile.transform, id = projectile.sprite_id)
}

//init a projectile
init_projectile :: proc(
	projectile_data: Projectile, 
	shoot_pos: Vec2, 
	dir: Vec2, 
	sprite_id: string
){
	append(&gs.projectiles, projectile_data)
	projectile := &gs.projectiles[len(gs.projectiles)-1]
	transform := &projectile.transform

	transform.pos = shoot_pos
	projectile.dir = dir
	transform.rot.z = linalg.to_degrees(linalg.atan2(projectile.dir.y, projectile.dir.x))
	projectile.sprite_id = sprite_id
	
	draw.init_sprite(img = projectile.img, transform = transform^, id = projectile.sprite_id)
}

remove_projectile :: proc(projectile: ^Projectile){
	//remove the projectile sprite
	draw.remove_object(projectile.sprite_id)
}



// ITEM HOLDER

//item holder is an obj that can display and update an entity with the item tag
Item_holder :: struct{
	transform: Transform,	
	item: es.Entity,
	sprite_id: Sprite_id,
	//if items like guns should be equipped
	equipped: bool,
}

//init an item holder and check for certain tags
init_item_holder :: proc(holder: ^Item_holder){

	item := holder.item
	assert(utils.contains(item.tags, es.Entity_tags.Item))

	#partial switch tag2 := item.tags[utils.get_next_index(item.tags, es.Entity_tags.Item)]; tag2{
	case .Projectile_weapon:
		if holder.equipped{
			pweapon := es.entity_get_component(entity = item.entity, component_type = Projectile_weapon) 
			init_projectile_weapon(pweapon)
		}
	}

	item_data := es.entity_get_component(entity = item.entity, component_type = Item_data)
	holder.sprite_id = init_item(&holder.transform, item_data^)
}


//update the item holder and check for certain tags
update_item_holder :: proc(
	holder: Item_holder, 
	look_dir: Vec2 = {1, 0}, 
	shoot_pos: Vec2 = {0, 0}
){
	//the players item
	item := holder.item
	#partial switch tag2 := item.tags[utils.get_next_index(item.tags, es.Entity_tags.Item)]; tag2{
	case .Projectile_weapon:
		if holder.equipped{
			pweapon := es.entity_get_component(entity = item.entity, component_type = Projectile_weapon) 
			update_projectile_weapon(pweapon, look_dir, shoot_pos)
		}		
	}

	item_data := es.entity_get_component(entity = item.entity, component_type = Item_data)
	update_item(holder.transform, item_data^, holder.sprite_id)
}

//gives an item to the item holder which potentially replaces the old one, the inits the holder
give_item :: proc(holder: ^Item_holder, item_id: string){
	assert(item_id in es.enteties)
	
	draw.remove_object(holder.sprite_id)
	holder.item = es.enteties[item_id]
	init_item_holder(holder)
}

