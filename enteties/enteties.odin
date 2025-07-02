package enteties

import "base:intrinsics"
import ecs "../lib/odin-ecs"
import "core:log"

ctx: ecs.Context

enteties: Enteties

// ================
//    :ENTETIES
// ================
/*
	Enteties uses the odin-ecs lib and is mainly meant for items and other stuff that can't be type specific
	( I need to be able to give any item to my player regardless of what type it is or what data it has )
*/

enteties_init :: proc(){
	ctx = ecs.init_ecs()

	defer ecs.deinit_ecs(&ctx)
}

Enteties :: map[string]Entity
Entity :: struct{
	entity: ecs.Entity,
	tags: [dynamic]Entity_tags
}

Entity_tags :: enum{
	Item,
	Projectile_weapon,
}

create_entity :: proc(id: string, tags: [dynamic]Entity_tags){
	enteties[id] = Entity{
		entity = ecs.create_entity(&ctx),
		tags = tags,
	}
}

entity_add_component :: proc(id: string, component: $T){
	temp, error := ecs.add_component(&ctx, enteties[id].entity, component)
	if error != .NO_ERROR do log.debug(error)
}

//get a component using an ecs.Entity or an id
entity_get_component :: proc{
	entity_entity_get_component,
	entity_id_get_component,
}

entity_entity_get_component :: proc(entity: ecs.Entity, $component_type: typeid) -> ^component_type{
	component, error := ecs.get_component(&ctx, entity, component_type)
	if error != .NO_ERROR do log.debug(error)
	return component
}

entity_id_get_component :: proc(id: string, $component_type: typeid) -> ^component_type{
	return entity_entity_get_component(enteties[id].entity, component_type)
}

entity_log_component_ptr  :: proc(entity: ecs.Entity, $component_type: typeid){
	component, error := ecs.get_component(&ctx, entity, component_type)
	if error != .NO_ERROR do log.debug(error)
	log.debug(&component)
}

//destroy an entity using an ecs.Entity or an id
destroy_entity :: proc{
	destroy_entity_entity,
	destroy_entity_id,
}

destroy_entity_entity :: proc(entity: ecs.Entity){
	ecs.destroy_entity(&ctx, entity)
}

destroy_entity_id :: proc(id: string){
	ecs.destroy_entity(&ctx, enteties[id].entity)
}


