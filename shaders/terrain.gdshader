shader_type spatial;

// Terrain shader with height variation
uniform sampler2D noise_texture : hint_default_white;
uniform float height_scale : hint_range(0.0, 10.0) = 3.0;
uniform float noise_scale : hint_range(0.01, 0.5) = 0.05;
uniform vec3 grass_color : source_color = vec3(0.29, 0.49, 0.14);
uniform vec3 dirt_color : source_color = vec3(0.55, 0.45, 0.33);
uniform vec3 road_color : source_color = vec3(0.18, 0.18, 0.18);

// Flat zones for buildings and roads (world positions)
uniform vec4 flat_zone_1 = vec4(-4.0, -4.0, 17.0, 20.0); // Existing house area (min_x, min_z, max_x, max_z)
uniform vec4 flat_zone_2 = vec4(25.0, -100.0, 35.0, 100.0); // Main road
uniform vec4 flat_zone_3 = vec4(-100.0, -5.0, 100.0, 5.0); // Oak Street
uniform vec4 flat_zone_4 = vec4(-100.0, 25.0, 100.0, 35.0); // Pine Street
uniform vec4 flat_zone_5 = vec4(-100.0, -35.0, 100.0, -25.0); // Maple Street

varying float height;
varying vec3 world_pos;

float get_noise_height(vec2 pos) {
    return texture(noise_texture, pos * noise_scale).r;
}

float is_in_flat_zone(vec2 pos) {
    // Check all flat zones
    if (pos.x >= flat_zone_1.x && pos.x <= flat_zone_1.z && 
        pos.y >= flat_zone_1.y && pos.y <= flat_zone_1.w) return 1.0;
    if (pos.x >= flat_zone_2.x && pos.x <= flat_zone_2.z && 
        pos.y >= flat_zone_2.y && pos.y <= flat_zone_2.w) return 1.0;
    if (pos.x >= flat_zone_3.x && pos.x <= flat_zone_3.z && 
        pos.y >= flat_zone_3.y && pos.y <= flat_zone_3.w) return 1.0;
    if (pos.x >= flat_zone_4.x && pos.x <= flat_zone_4.z && 
        pos.y >= flat_zone_4.y && pos.y <= flat_zone_4.w) return 1.0;
    if (pos.x >= flat_zone_5.x && pos.x <= flat_zone_5.z && 
        pos.y >= flat_zone_5.y && pos.y <= flat_zone_5.w) return 1.0;
    return 0.0;
}

float smooth_flat_zone(vec2 pos, float blend_dist) {
    float flat = is_in_flat_zone(pos);
    if (flat > 0.5) return 0.0;
    
    // Check distance to flat zones for smooth blending
    float min_dist = 1000.0;
    
    // Distance to flat_zone_1
    float dx1 = max(flat_zone_1.x - pos.x, max(pos.x - flat_zone_1.z, 0.0));
    float dy1 = max(flat_zone_1.y - pos.y, max(pos.y - flat_zone_1.w, 0.0));
    min_dist = min(min_dist, length(vec2(dx1, dy1)));
    
    // Distance to roads (simplified)
    float road_dist = min(abs(pos.x - 30.0), min(abs(pos.y), min(abs(pos.y - 30.0), abs(pos.y + 30.0))));
    min_dist = min(min_dist, road_dist);
    
    return smoothstep(0.0, blend_dist, min_dist);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    float noise_val = get_noise_height(world_pos.xz);
    float flat_factor = smooth_flat_zone(world_pos.xz, 8.0);
    
    height = noise_val * height_scale * flat_factor;
    VERTEX.y += height;
}

void fragment() {
    // Mix grass and dirt based on height and noise
    float dirt_factor = smoothstep(0.3, 0.7, height / height_scale);
    vec3 base_color = mix(grass_color, dirt_color, dirt_factor * 0.3);
    
    // Add slight variation
    float variation = texture(noise_texture, world_pos.xz * 0.1).r * 0.1;
    base_color += vec3(variation) - 0.05;
    
    ALBEDO = base_color;
    ROUGHNESS = 0.9;
    METALLIC = 0.0;
}
