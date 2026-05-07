package hello_world

import sdl "vendor:sdl3";
import "core:fmt";
import "core:math";

zoom:f64:200.0;
WIDTH:i32=1280;
HEIGHT:i32=720;
@require_results
get_driver_names::proc()->(drivers:[]cstring,count:i32){
    count=sdl.GetNumRenderDrivers();
    drivers=make([]cstring,count);
    for d in 0..<count{
        drivers[d]=sdl.GetRenderDriver(d);
    }
    return;
}
set_driver_by_priority::proc(priority_list:[]cstring)->(driver:cstring){
    driver_list, _:=get_driver_names();
    defer delete(driver_list);
    for priority in priority_list{
        for d in driver_list{
            if d==priority{
                return priority;
            }
        }
    }
    return;
}

Point3D::struct{x,y,z:f64};
NTriangle::struct{v0,v1,v2: Point3D};


Project::proc(nt:NTriangle)->Triangle{
	/*implement procedure to project the 3d triangle to 2d.
	x=(x/z)*f &y=(y/z)*f(f is the focal length "zoom")
	z SHOULD NEVER BE NEGATIVE, ALWAYS POSITIVE (USE AN OFFSET->5.0)
	*/
	t:=Triangle{{0,0,},{0,0,},{0,0,}};
	t.v0.x=((f32(nt.v0.x)*f32(zoom))/(f32(nt.v0.z)+5.0))+f32(WIDTH/2);
	t.v0.y=((f32(nt.v0.y)*f32(zoom))/(f32(nt.v0.z)+5.0))+f32(HEIGHT/2);

	t.v1.x=((f32(nt.v1.x)*f32(zoom))/(f32(nt.v1.z)+5.0))+f32(WIDTH/2);
	t.v1.y=((f32(nt.v1.y)*f32(zoom))/(f32(nt.v1.z)+5.0))+f32(HEIGHT/2);

	t.v2.x=((f32(nt.v2.x)*f32(zoom))/(f32(nt.v2.z)+5.0))+f32(WIDTH/2);
	t.v2.y=((f32(nt.v2.y)*f32(zoom))/(f32(nt.v2.z)+5.0))+f32(HEIGHT/2);
	return t;
}
TranslateZ::proc(p:Point3D,dz:f64)->Point3D{
	np:=Point3D{p.x,p.y,p.z+dz};
	return np;
}

RotateXZ::proc(p:Point3D,angle:f64)->Point3D{
	np:=p;
	old_x:=np.x;
	np.x=old_x*math.cos(angle)-np.z*math.sin(angle);
	np.z=old_x*math.sin(angle)+np.z*math.cos(angle);
	return np;
}

Triangle::struct{v0,v1,v2: sdl.FPoint};
dz:f64=0;//offset
angle:f64=0;//angle
sierpinksi::proc(r: ^sdl.Renderer, t:Triangle, depth:int){
    if depth==0{
        t_raw:=[4]sdl.FPoint{t.v0,t.v1,t.v2,t.v0};
        sdl.RenderLines(r, raw_data(t_raw[:]),4);
    }
    if depth>0{
        sierpinksi(r,{t.v0,(t.v0+t.v1)/2,(t.v0+t.v2)/2},depth-1);//top
        sierpinksi(r,{t.v1,(t.v1+t.v2)/2,(t.v0+t.v1)/2},depth-1);//left
        sierpinksi(r,{t.v2,(t.v0+t.v2)/2,(t.v1+t.v2)/2},depth-1);//right
    }
}
GetFAverage::proc(x,y,z:f64,sides:f64)->f64{
	return (x+y+z)/sides;
}

GetApex::proc(tri:NTriangle)->Point3D{
	newPoint:Point3D;
	newPoint.x=GetFAverage(tri.v0.x,tri.v1.x,tri.v2.x,3.0);
	newPoint.y=GetFAverage(tri.v0.y,tri.v1.y,tri.v2.y,3.0);
	newPoint.z=GetFAverage(tri.v0.z,tri.v1.z,tri.v2.z,3.0);
	return newPoint;
}

FindSides::proc(nT:NTriangle)->[3]NTriangle{
	newTriArray:[3]NTriangle;
	apex:=GetApex(nT);
	apex.y+=4.0;
	newTriArray[0]={nT.v0,nT.v1,apex};
	newTriArray[1]={nT.v0,apex,nT.v2};
	newTriArray[2]={apex,nT.v1,nT.v2};

	return newTriArray;
}
//nTri:=NTriangle{{0,-2,-5},{-2,2,-3},{2,2,-3}};
bTri:=NTriangle{{-3,0,-1},{3,0,1},{0,0,3}};
// s1Tri:=NTriangle{{-2,-2,-2},{2,-2,-2},{0,2,0}};
// s2Tri:=NTriangle{{0,2,0},{2,-2,-2},{0,-2,2}};
// s3Tri:=NTriangle{{-2,-2,-2},{0,2,0},{0,-2,2}};

main :: proc(){
    fmt.println("Hello World!");
	
    meta_ok:=sdl.SetAppMetadata("3d SierPinski?",".1","");

    if !sdl.Init({.VIDEO,.EVENTS}){
        fmt.eprintln("Failed to initialize SDL3:", sdl.GetError());
        return;
    }
    defer sdl.Quit();
    
    driver:cstring;
    when ODIN_OS==.Linux{
        driver=set_driver_by_priority({"vulkan","gpu","opengl","software"});
    }else when ODIN_OS==.Windows{
        driver=set_driver_by_priority({"direct3d12", "direct3d11", "direct3d", "gpu", "opengl", "software"});
    }else{
        driver = set_driver_by_priority({"gpu", "opengl", "software"});
    }

    if driver==nil{
        fmt.eprintfln("%s %v","Unable to load driver from priority list for",ODIN_OS);
    }

    window :=sdl.CreateWindow("My Odin Engine",WIDTH,HEIGHT,{.RESIZABLE});
    renderer:=sdl.CreateRenderer(window,driver);
    sdl.SetRenderLogicalPresentation(renderer,WIDTH,HEIGHT,.LETTERBOX);
    
	defer sdl.DestroyWindow(window);
	defer sdl.DestroyRenderer(renderer);

    vsync_ok:=sdl.SetRenderVSync(renderer,1);
    if !vsync_ok{
        fmt.eprintln("Failed to enable VSync");
    }
    display_id      := sdl.GetDisplayForWindow(window);
	display_mode    := sdl.GetCurrentDisplayMode(display_id);
	refresh_rate    := display_mode.refresh_rate;
	vsync_enabled   := true;
	fps_cap_enabled := true;
	fps_target      := 60;
	s_depth         := 5;
	fps: f64=1;

    color:sdl.FColor;
    color_paused:bool;

    drivers, _:=get_driver_names();
    defer delete(drivers);

controls := [][]cstring {
		{"Quit",           "Q", "ESC"},
		{"Pause Color",    "P", "LMB"},
		{"Toggle Vsync",   "V", ""},
		{"Toggle FPS Cap", "F", ""},
		{"Triangle Depth", "0", "to 9"},
	}

    
    if(window==nil){
        fmt.eprintln("Failed to create window:", sdl.GetError());
        return;
    }


    // Main loop
	main_loop: for {

		// Get counter before whole frame
		frame_start := sdl.GetTicksNS()

		// Handle events
		for e: sdl.Event; sdl.PollEvent(&e); /**/ {
			#partial switch e.type {
			case .QUIT:
				break main_loop;
			case .WINDOW_CLOSE_REQUESTED:
				break main_loop;
			case .KEY_UP:
				switch e.key.key {
					case sdl.K_0..=sdl.K_9:
						s_depth = int(e.key.key - 0x00000030);
					case sdl.K_P:
						color_paused = !color_paused;
					case sdl.K_ESCAPE:
						break main_loop;
					case sdl.K_Q:
						break main_loop;
					case sdl.K_V:
						vsync_enabled = !vsync_enabled;
						sdl.SetRenderVSync(renderer, vsync_enabled ? 1 : sdl.RENDERER_VSYNC_DISABLED);
					case sdl.K_F:
						fps_cap_enabled = !fps_cap_enabled;
				}
			case .MOUSE_BUTTON_UP:
				switch e.button.button {
				case sdl.BUTTON_LEFT:
					color_paused = !color_paused;
				}
			}
		}

		// Smoothly change color on each loop if not paused
		if !color_paused {
			now    := f64(frame_start) / 1000000000.000; // convert to seconds
			color.r = f32(0.500 + 0.500 * sdl.sin(now));
			color.g = f32(0.500 + 0.500 * sdl.sin(now + math.PI * 2 / 3));
			color.b = f32(0.500 + 0.500 * sdl.sin(now + math.PI * 4 / 3));
			color.a = sdl.ALPHA_OPAQUE_FLOAT; // opaque
		}

		// Set new background color
		sdl.SetRenderDrawColorFloat(renderer, color.r, color.g, color.b, color.a)
		sdl.RenderClear(renderer)

		//Vars for 3d rotation
		dt:=1.0/fps;
		dz+=1.0*dt;
		angle+=2*math.PI*dt;
		// Set color compliment of background and draw triangle(s)

		//Trying to rotate a 3d triangle 
		sdl.SetRenderDrawColorFloat(renderer, 1 - color.r, 1 - color.g, 1 - color.b, 255)
		t := Triangle{{466, 40}, {212, 460}, {720, 460}}
		
		// nTri.v0=RotateXZ(nTri.v0,2*math.PI*dt);
		// nTri.v1=RotateXZ(nTri.v1,2*math.PI*dt);
		// nTri.v2=RotateXZ(nTri.v2,2*math.PI*dt);
		// nTri.v0=TranslateZ(nTri.v0,1.0*dt);
		// nTri.v1=TranslateZ(nTri.v1,1.0*dt);
		// nTri.v2=TranslateZ(nTri.v2,1.0*dt);

		/*Make a triangle array of sides*/
		triArray:=FindSides(bTri);

		//rotate base and sides
		bTri.v0=RotateXZ(bTri.v0,2*math.PI*dt*.2);
		bTri.v1=RotateXZ(bTri.v1,2*math.PI*dt*.2);
		bTri.v2=RotateXZ(bTri.v2,2*math.PI*dt*.2);
		for &NTriangle in triArray{
			NTriangle.v0=RotateXZ(NTriangle.v0,2*math.PI*dt*.2)
			NTriangle.v1=RotateXZ(NTriangle.v1,2*math.PI*dt*.2)
			NTriangle.v2=RotateXZ(NTriangle.v2,2*math.PI*dt*.2)
		}


		// s1Tri.v0=RotateXZ(s1Tri.v0,2*math.PI*dt*.2);
		// s1Tri.v1=RotateXZ(s1Tri.v1,2*math.PI*dt*.2);
		// s1Tri.v2=RotateXZ(s1Tri.v2,2*math.PI*dt*.2);

		// s2Tri.v0=RotateXZ(s2Tri.v0,2*math.PI*dt*.2);
		// s2Tri.v1=RotateXZ(s2Tri.v1,2*math.PI*dt*.2);
		// s2Tri.v2=RotateXZ(s2Tri.v2,2*math.PI*dt*.2);

		// s3Tri.v0=RotateXZ(s3Tri.v0,2*math.PI*dt*.2);
		// s3Tri.v1=RotateXZ(s3Tri.v1,2*math.PI*dt*.2);
		// s3Tri.v2=RotateXZ(s3Tri.v2,2*math.PI*dt*.2);

		t=Project(bTri);
		t2:=Project(triArray[0]);
		t3:=Project(triArray[1]);
		t4:=Project(triArray[2]);

		sierpinksi(renderer, t, s_depth);
		sierpinksi(renderer, t2, s_depth);
		sierpinksi(renderer, t3, s_depth);
		sierpinksi(renderer, t4, s_depth);


		// Set font color and some debug text
		r: f32 // mini row iterator
		row :: proc(row: ^f32, height: f32) -> f32 { row^ += height; return row^ }
		sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
		sdl.RenderDebugText(renderer, 10, row(&r, 10), "hellope world!")
		sdl.RenderDebugText(renderer, 10, row(&r, 20), fmt.ctprintf("%-16s%v", "Triangle Depth:", s_depth))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "Color Paused:", color_paused))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "VSync Enabled:", vsync_enabled))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "Refresh Rate:", refresh_rate))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "FPS Capped:", fps_cap_enabled))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%i", "FPS Target:", fps_target))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%.2f", "FPS Current:", fps))
		sdl.RenderDebugText(renderer, 10, row(&r, 20), "Found Drivers:")
		for d in drivers {
			sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%s %s", d, d == driver ? "(Loaded)":""))
		}
		sdl.RenderDebugText(renderer, 10, row(&r, 20), "Controls:")
		for c in controls {
			sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%-2s%s", c[0], c[1], c[2]))
		}

		// free context.temp_allocator from use of fmt.ctprint
		free_all(context.temp_allocator)

		// Present renderer
		sdl.RenderPresent(renderer)

		// Get counter after whole frame
		frame_end := sdl.GetTicksNS()
		
		// Cap fps if enabled
		npf_target := u64(1000000000 / fps_target) // nanoseconds per frame target
		if fps_cap_enabled && (frame_end - frame_start) < npf_target {
			sleep_time := npf_target - (frame_end - frame_start)
			sdl.DelayPrecise(sleep_time)
			frame_end = sdl.GetTicksNS() // Update frame_end counter to include sleep_time for fps calculation
		}

		// update fps tracker
		fps = 1000000000.000 / f64(frame_end - frame_start)
	}
    // running :=true;
    // for running{
    //     event:sdl.Event;

    //     for sdl.PollEvent(&event){
    //         #partial switch event.type{
    //             case .QUIT:
    //                 running=false;
    //         }
    //     }
    // }
    // defer sdl.DestroyWindow(window);
}