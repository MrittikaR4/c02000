extends RefCounted
## Procedural graphics helpers: everything is generated in code, no imported assets.

const PLANET_SHADER := preload("res://shaders/planet.gdshader")
const GLOW_SHADER := preload("res://shaders/glow.gdshader")



static func glow(tint: Color, size: float, opacity: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("opacity", opacity)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func set_glow_opacity(mi: MeshInstance3D, v: float) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("opacity", v)


static func planet_mat(kind: int, seed_v: float, a: Color, b: Color, c: Color = Color.WHITE, scale_v: float = 1.0, bands: float = 20.0, spot: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLANET_SHADER
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("scale", scale_v)
	m.set_shader_parameter("col_a", a)
	m.set_shader_parameter("col_b", b)
	m.set_shader_parameter("col_c", c)
	m.set_shader_parameter("bands", bands)
	m.set_shader_parameter("spot", spot)
	return m


static func std_mat(color: Color, metal: float = 0.5, rough: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m


static func unshaded_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Flat annulus in the XZ plane. UV.x = 0 inner edge .. 1 outer edge, UV.y = angle * uv_turns.
static func annulus(inner: float, outer: float, segs: int = 128, uv_turns: float = 3.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var p0i := Vector3(cos(a0) * inner, 0, sin(a0) * inner)
		var p0o := Vector3(cos(a0) * outer, 0, sin(a0) * outer)
		var p1i := Vector3(cos(a1) * inner, 0, sin(a1) * inner)
		var p1o := Vector3(cos(a1) * outer, 0, sin(a1) * outer)
		var v0 := float(i) / segs * uv_turns
		var v1 := float(i + 1) / segs * uv_turns
		for t in [[p0i, Vector2(0, v0)], [p0o, Vector2(1, v0)], [p1o, Vector2(1, v1)], [p0i, Vector2(0, v0)], [p1o, Vector2(1, v1)], [p1i, Vector2(0, v1)]]:
			st.set_uv(t[1])
			st.add_vertex(t[0])
	return st.commit()


## A lumpy low-poly rock mesh (flat shaded), same idea as the perturbed icosahedrons in the web version.
static func rock_mesh(seed_v: int, rings: int = 5, radial: int = 9) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = radial
	sphere.rings = rings
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.3
	var fine := FastNoiseLite.new()
	fine.seed = seed_v + 77
	fine.frequency = 3.4
	for i in verts.size():
		var v := verts[i]
		var s := 0.62 + 0.62 * (noise.get_noise_3dv(v * 2.0) * 0.5 + 0.5) + 0.14 * fine.get_noise_3dv(v * 3.0)
		verts[i] = v * s
	arrays[Mesh.ARRAY_VERTEX] = verts
	var src := ArrayMesh.new()
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.deindex()
	st.generate_normals()
	return st.commit()


## One-shot spark burst using CPUParticles3D; frees itself.
static func burst(parent: Node, pos: Vector3, count: int, color: Color, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 1.0
	p.explosiveness = 1.0
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed * 1.2
	p.gravity = Vector3.ZERO
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	var t := parent.get_tree().create_timer(2.0)
	t.timeout.connect(p.queue_free)
