.pragma library
function family(id,d,color) {
    return {id:id,direction3D:d,color:color};
}
function preset(key) {
    const X="#fbbf24",Y="#67e8f9",Z="#a7f3d0",P="#c4b5fd";
    if(key==="1") return {projection:"rectilinear",description:"One finite depth VP; X/Y at infinity",
        families:[family("depth",[0,0,1],Z),family("horizontal",[1,0,0],X),
                  family("vertical",[0,1,0],Y)]};
    if(key==="2") return {projection:"rectilinear",cameraTiltRadians:0,focalScale:0.33,
        description:"Two finite horizontal VPs; vertical infinity",
        families:[family("left",[1,0,1],X),family("right",[-1,0,1],Y),
                  family("vertical",[0,1,0],Z)]};
    if(key==="3") return {projection:"rectilinear",cameraTiltRadians:0.8,focalScale:0.22,
        description:"Camera tilt makes vertical VP finite; three non-collinear VPs",
        families:[family("left",[1,0,1],X),family("right",[-1,0,1],Y),
                  family("vertical",[0,1,0],Z)]};
    if(key==="4") return {projection:"equidistantFisheye",description:"Four front-rim antipodal endpoints",
        families:[family("X rim",[1,0,0],X),family("Y rim",[0,1,0],Y)]};
    if(key==="5") return {projection:"equidistantFisheye",description:"Four rim endpoints + forward center; rear outside FOV",
        families:[family("X rim",[1,0,0],X),family("Y rim",[0,1,0],Y),
                  family("forward",[0,0,1],Z)]};
    if(key==="6") return {projection:"equirectangular",description:"Six poles in full 360 x 180 map",
        families:[family("X poles",[1,0,0],X),family("Y poles",[0,1,0],Y),
                  family("Z poles",[0,0,1],Z)]};
    const dirs=[[1,0.2,1],[0.3,1,1],[-1,0.4,1],[-0.2,-1,1],
                [0.7,-0.5,1],[-0.8,-0.3,1],[0.2,0.6,0.4],[-0.4,0.7,0.6]];
    return {projection:"rectilinear",description:"Eight independent world-direction families",
        families:dirs.map((d,i)=>family("N"+(i+1),d,[X,Y,Z,P][i%4]))};
}
