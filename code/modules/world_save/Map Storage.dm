/datum/proc/after_load()
	return
proc/mdlist2params(list/l)
                           //This converts a multidimensional list into a set of parameters. The
                           //output is in the following format: "name1=value1&name2=(name3=value3)"
                           //Notes: This can convert normal lists as well as multidimensional lists
                           //Warning: Beware of circular references. This will cause in infinite loop.
                                //If you know there is going to be a circular reference, create a new list
                                //and pull out the reference
	if(!istype(l,/list)) return
	var/rvalue,e = 1
	for(var/a in l)
		if(istype(l[a],/list) && length(l[a]))
			rvalue += list2params(l.Copy(e,l.Find(a)))
			rvalue += "&[a]=([mdlist2params(l[a])])"
			e = l.Find(a) + 1
		else continue
	if(e == 1) rvalue += list2params(l)
	return rvalue

proc/params2mdlist(params) //This converts a parameter text string, output by mdlist2params(), into
                           //a multidimensional list.
                           //Notes: It will work for parameters output by list2params() as well.
    if(!istext(params)) return
    var/list/rlist = list()
    var/len = length(params)
    var/element = null
    var/a = 0,p_count = 1
    while(a <= len)
        a ++
        if(findtext(params,"&",a,a+1))
            rlist += params2list(copytext(params,1,a))
            params = copytext(params,a+1)
            len = length(params)
            a = 1
        if(findtext(params,"(",a,a+1))
            element = copytext(params,1,a-1)
            params = copytext(params,a+1)
            len = length(params)
            p_count = 1
            while(p_count > 0)
                a ++
                if(findtext(params,"(",a,a+1)) p_count ++
                if(findtext(params,")",a,a+1)) p_count --
                if(a >= len - 1) break
            rlist[element] = params2mdlist(copytext(params,1,a+1))
            params = copytext(params,a+2)
            len = length(params)
            a = 1
    rlist += params2list(copytext(params,1))
    return rlist

var/map_storage/map_storage = new("SS13")
/*************************************************************************
ATOM ADDITIONS
**************************************************************************/
datum
	var
		load_contents = 0
		should_save = 1
		map_storage_saved_vars = ""
atom
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;id"
	load_contents = 1
mob
/obj/effect
	should_save = 0
/*************************************************************************
MAP STORAGE DATUM
**************************************************************************/
map_storage

	var
		// These are atom types for the map saver to ignore. Objects of these type will
		// not be saved with everything else.
		list/ignore_types = list(/mob, /atom/movable/lighting_overlay)

		// If a text string is specified here, then you will be able to use this as a
		// backdoor password which will let you access any maps. This is primary for
		// developers who need to be able to access maps created by other people for
		// debugging purposes.
		backdoor_password = null

		// This text string is tacked onto all saved passwords so that their md5 values
		// will be different than what the password's hash would normally be, providing
		// a bit of extra protection against md5 hash directories.
		game_id = "SS13"




		// INTERNAL VARIABLES - SHOULD NOT BE ALTERED BY USERS

		// List of object types. This will be converted to params and encrypted when saved.
		list/object_reference = list()
		list/obj_references = list()
		list/existing_references = list()
		list/saving_references = list()
		list/all_loaded = list()
		list/datum_reference = list()
		list/dtm_references = list()
		
	New(game_id, backdoor, ignore)
		..()
		if(game_id)
			src.game_id = game_id
		if(backdoor)
			src.backdoor_password = backdoor
		if(ignore)
			src.ignore_types = ignore
		return
	
	
	proc/Load_Entry(savefile/savefile, var/ind, var/turf/old_turf, var/atom/starting_loc, var/atom/replacement)
		if(existing_references["[ind]"])
			if(starting_loc)
				var/atom/movable/A = existing_references["[ind]"]
				A.loc = starting_loc
			return existing_references["[ind]"]
		savefile.cd = "/entries/[ind]"
		var/type = savefile["type"]
		var/atom/movable/object
		if(!type)
			message_admins("no type found! ind: [ind] starting_loc: [starting_loc] ")
			return
		if(old_turf)
		//	old_turf.blocks_air = 1
			var/finished = 0
			while(!finished)
				finished = 1
			var/xa = old_turf.x
			var/ya = old_turf.y
			var/za = old_turf.z
			old_turf.ChangeTurf(type, FALSE, FALSE)
			object = locate(xa,ya,za)
		else if(replacement)
			object = replacement
		else
			object = new type(starting_loc)
		if(!object)
			message_admins("object not created, ind: [ind] type:[type]")
			return
		all_loaded += object
		existing_references["[ind]"] = object
		for(var/v in savefile.dir)
			savefile.cd = "/entries/[ind]"
			if(v == "type")
				continue
			else if(v == "content")
				if(savefile[v])
				var/list/refs = params2list(savefile[v])
				var/finished = 0
				while(!finished)
					finished = 1
					for(var/obj/ob in object.contents)
						finished = 0
						ob.forceMove(locate(200, 100, 2))
						ob.Destroy()
				for(var/x in refs)
					var/atom/movable/A = Load_Entry(savefile, x, null, object)
			else if(findtext(savefile[v], "**list"))
				var/x = savefile[v]
				var/list/fixed = string_explode(x, "list")
				x = fixed[2]
				var/list/lis = params2list(x)
				var/list/final_list = list()
				if(lis.len)
					var/firstval = lis[1]
					for(var/xa in lis)
						if(findtext(xa, "**entry"))
							var/list/fixed2 = string_explode(xa, "entry")
							var/y = fixed2[2]
							var/atom/movable/A = Load_Entry(savefile, y)
							final_list += A
						else
							final_list += Numeric(x)
				object.vars[v] = final_list
			else if(findtext(savefile[v], "**entry"))
				var/x = savefile[v]
				var/list/fixed = string_explode(x, "entry")
				x = fixed[2]
				var/atom/movable/A = Load_Entry(savefile, x)
				object.vars[v] = A
			else if(savefile[v] == "**null")
				object.vars[v] = null
			else if(v == "req_access_txt")
				object.vars[v] = savefile[v]
			else if(savefile[v] == "**emptylist")
				object.vars[v] = list()
			else
				savefile.cd = "/entries/[ind]"
				object.vars[v] = Numeric(savefile[v])
			savefile.cd = "/entries/[ind]"
		savefile.cd = ".."
		return object
	proc/BuildVarDirectory(savefile/savefile, atom/A, var/contents = 0)
		if(!A.should_save)
			return
		// If this object has no variables to save, skip it
		var/ind = saving_references.Find(A)
		var/ref = 0
		if(ind)
			return ind
		else
			saving_references += A
			ref = saving_references.len
		savefile.cd = "/entries/[ref]"
		savefile["type"] = A.type
		var/list/content_refs = list()
		if(A.load_contents)
			var/atom/movable/Ad = A
			if(contents)
				for(var/obj/content in Ad.contents)
					if(content.loc != Ad) continue
					var/conparams = BuildVarDirectory(savefile, content, 1)
					savefile.cd = "/entries/[ref]"
					if(!conparams)
						continue
					content_refs += "[conparams]"
			var/final_params = list2params(content_refs)
			savefile.cd = "/entries/[ref]"
			savefile["content"] = final_params
		
		// Add any variables changed and their associated values to a list called changed_vars.
		var/list/changed_vars = list()
		var/list/changing_vars = params2list(A.map_storage_saved_vars)
		if(istype(A, /atom/movable))
			var/atom/movable/AM = A
			if(contents && AM.load_datums)
				changing_vars += "reagents"
				changing_vars += "air_contents"
		for(var/v in changing_vars)
			savefile.cd = "/entries/[ref]"
			if(A.vars.Find(v))
				if(istype(A.vars[v], /obj))
					var/atom/movable/varob = A.vars[v]
					var/conparams = BuildVarDirectory(savefile, varob, 1)
					if(!conparams)
						continue
					savefile.cd = "/entries/[ref]"
					savefile["[v]"] = "**entry[conparams]"  
				else if(istype(A.vars[v], /datum))
					var/atom/movable/varob = A.vars[v]
					var/conparams = BuildVarDirectory(savefile, varob, 1)
					if(!conparams)
						continue
					savefile.cd = "/entries/[ref]"
					savefile["[v]"] = "**entry[conparams]"  
				else if(istype(A.vars[v], /list))
					var/list/lis = A.vars[v]
					if(lis.len)
						var/list/fixed_list = list()
						for(var/firstval in lis)
							if(istype(firstval, /obj))
								var/conparams = BuildVarDirectory(savefile, firstval, 1)
								if(!conparams)
									continue
								fixed_list += "**entry[conparams]"
							else if(istype(firstval, /datum))
								var/conparams = BuildVarDirectory(savefile, firstval, 1)
								if(!conparams)
									continue
								fixed_list += "**entry[conparams]"
							else
								fixed_list += firstval
						savefile.cd = "/entries/[ref]"
						savefile["[v]"] = "**list[list2params(fixed_list)]"
					else
						if(A.vars[v] != initial(A.vars[v]))
							savefile.cd = "/entries/[ref]"
							savefile["[v]"] = "**emptylist"
				else if(A.vars[v] != initial(A.vars[v]) || v == "pixel_x" || v == "pixel_y")
					savefile.cd = "/entries/[ref]"
					savefile["[v]"] = A.vars[v]
		savefile.cd = ".."
		return ref
			


// Returns true if the value is purely numeric, return false if there are non-numeric
// characters contained within the text string.
	proc/IsNumeric(text)
		if(isnum(text))
			return 1
		for(var/n in 1 to length(text))
			var/ascii = text2ascii(text, n)
			if(ascii < 45 || ascii > 57)
				return 0
			if(ascii == 47)
				return 0
		return 1



// If the value is numeric, convert it to a number and return the number value. If
// the value is text, then return it as it is.
	proc/Numeric(text)
		if(IsNumeric(text))
			return text2num(text)
		else
			if(findtext(text, "e+"))
				var/list/nums = string_explode(text, "e+")
				if(nums.len > 1 && nums.len < 3)
					var/integer = text2num(nums[1])
					var/exp = text2num(nums[2])
					if(IsNumeric(integer) && IsNumeric(exp))
						return integer*10**exp
			return text



map_storage
	proc/Save_Char(client/C, var/datum/mind/H, var/mob/living/carbon/human/Firstbod, var/slot = 0)
		var/ckey = ""
		saving_references = list()
		existing_references = list()
		var/mob/current
		if(!H)
			message_admins("trying to save char without mind")
			return
		if(H.current && H.current.ckey && !Firstbod)
			ckey = H.current.ckey
			slot = H.char_slot
			current = H.current
		else if(Firstbod)
			ckey = C.ckey
			current = Firstbod
		fdel("char_saves/[ckey]/[slot].sav")
		var/savefile/savefile = new("char_saves/[ckey]/[slot].sav")
		var/bodyind = BuildVarDirectory(savefile, current, 1)
		var/mindind = BuildVarDirectory(savefile, H, 1)
		var/locind = 0
		if(istype(current.loc, /obj))
			locind = BuildVarDirectory(savefile, current.loc, 1)
			
		savefile.cd = "/data"
		savefile["body"] = bodyind
		savefile["mind"] = mindind
		savefile["loc"] = locind
		return 1
	proc/Load_Char(var/ckey, var/slot, var/datum/mind/M, var/transfer = 0)
		if(!ckey)
			message_admins("Load_Char without ckey")
			return
		if(!slot)
			message_admins("Load_char without slot")
			return
		
		all_loaded = list()
		existing_references = list()
		all_loaded = list()
		var/savefile/savefile = new("char_saves/[ckey]/[slot].sav")
		savefile.cd = "/data"
		var/bodyind = savefile["body"]
		var/mindind = savefile["mind"]
		var/locind = savefile["loc"]
		var/loc = null
		if(locind != "0")
			loc = Load_Entry(savefile, locind)
		var/mob/mob = Load_Entry(savefile, bodyind)
		if(!mob)
			return
		if(!M)
			mob.mind = new()
			M = mob.mind
		var/datum/mind/mind = Load_Entry(savefile, mindind, null, null, M)
		if(!savefile)
			message_admins("savefile not found!")
			return
			
		for(var/datum/dat in all_loaded)
			dat.after_load()
		for(var/atom/movable/ob in all_loaded)
			ob.initialize()
			ob.after_load()
			if(ob.load_datums)
				if(ob.reagents)
					ob.reagents.my_atom = ob
			if(istype(ob, /turf/simulated))
				var/turf/simulated/Te = ob
				//Te.blocks_air = initial(Te.blocks_air)
				Te.new_air()
				
		if(transfer)
			M.transfer_to(mob)
		if(loc)
			return loc
		else
			return mob
// Saves all of the turfs and objects within turfs to their own directories withn
// the specifeid savefile name. If objects or turfs have variables to keep track
// of, it will check to see if those variables have been modified and record the
// new values of any modified variables along with the object. It uses an object
// reference, which records each object type as a position in a list so that it
// can be references using a number instead of a fully written out type class.
// You can also specify a name and password for the map, along with any extra
// variables (in params format) that you want saved along with the map file.
	proc/Save(savefile/savefile, list/areas, extra)

		// Abort if no filename specified.
		if(!savefile)
			return 0
		saving_references = list()
		existing_references = list()
		// ***** MAP SECTION *****
		for(var/A in areas)
			for(var/turf/turf in get_area_turfs(A))
				var/ref = BuildVarDirectory(savefile, turf, 1)
				if(!ref)
					message_admins("[turf] failed to return a ref!")
				savefile.cd = "/map/[turf.z]/[turf.y]"
				savefile["[turf.x]"] = ref
				
		return 1

	
			
// Loading a file is pretty straightforward - you specify the savefile to load from
// (make sure its an actual savefile, not just a file name), and if necessary you
// include the savefile's password as an argument. This will automatically check to
// make sure that the file provided is a valid map file, that the password matches,
// and that the verification values are what they're supposed to be (meaning the
// file has not been tampered with). Once everything is checked, it will resize the
// world map to fit the saved map, then unload all saved objects. Finally, any extra
// values that you included in the savefile will be returned by this function as
// an associative list.
	proc/Load(savefile/savefile, password)
		all_loaded = list()
		existing_references = list()
		// Make sure a map file is provided.
		if(!savefile)
			return
		savefile.cd = "/map"
		for(var/z in savefile.dir)
			savefile.cd = "/map/[z]"
			for(var/y in savefile.dir)
				savefile.cd = "/map/[z]/[y]"
				for(var/x in savefile.dir)
					var/turf_ref = savefile["[x]"]
					if(!turf_ref)
						message_admins("turf_ref not found, x: [x]")
						continue
					var/turf/old_turf = locate(text2num(x), text2num(y), text2num(z))
					Load_Entry(savefile, turf_ref, old_turf)
					savefile.cd = "/map/[z]/[y]"
		for(var/datum/dat in all_loaded)
			dat.after_load()
		for(var/atom/movable/ob in all_loaded)
			ob.initialize()
			ob.after_load()
			if(ob.load_datums)
				if(ob.reagents)
					ob.reagents.my_atom = ob
			if(istype(ob, /turf/simulated))
				var/turf/simulated/Te = ob
				//Te.blocks_air = initial(Te.blocks_air)
				Te.new_air()
/*************************************************************************
SUPPLEMENTARY FUNCTIONS
**************************************************************************/

map_storage

	// These is called routinely as the load and save functions make progress.
	// If you want to display how much of the map has been saved or loaded
	// somewhere, you can use this function to do it.

	proc/SaveOutput(percent)
		return

	proc/LoadOutput(percent)
		return

	// This is called when loading a map after all the verification and
	// password stuff is completed so that the map can have a fresh template
	// to work with.
	proc/ClearMap()
		for(var/turf/T in world)
			for(var/atom/movable/A in T)
				if(ismob(A))
					var/mob/M = A
					if(M.client)
						M.loc = null
						continue
				del(A)
			del(T)
		return
