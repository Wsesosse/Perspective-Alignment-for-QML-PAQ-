import QtQuick
import "ProjectionMath.js" as Projection
import "DirectionFamilies.js" as Families
import "GuideConstruction.js" as Guides
import "ProjectionFixtures.js" as Fixtures

QtObject {
    id: scene
    objectName: "sceneController"
    property string projection: "rectilinear"
    property string presetKey: "2"
    property string presetDescription: ""
    property string fixtureProjection: "rectilinear"
    property real cameraTiltRadians: 0
    property real focalScale: 0.33
    property var directionFamilies: []
    property real viewportWidth: 900
    property real viewportHeight: 560
    property real devicePixelRatio: 1
    property real angularToleranceRad: Math.PI/1800 // 0.1 degree
    property real pixelTolerancePhysical: 0.5
    property int geometryRevision: 0
    property int pointerPressCount: 0
    property int pointerMoveCount: 0
    onProjectionChanged: geometryRevision++
    onCameraTiltRadiansChanged: geometryRevision++
    onFocalScaleChanged: geometryRevision++
    onDirectionFamiliesChanged: geometryRevision++
    onViewportWidthChanged: geometryRevision++
    onViewportHeightChanged: geometryRevision++
    onDevicePixelRatioChanged: geometryRevision++
    onAngularToleranceRadChanged: geometryRevision++
    onPixelTolerancePhysicalChanged: geometryRevision++

    readonly property var snapshot: {
        const revision=geometryRevision
        const c=Projection.config(projection,viewportWidth,viewportHeight,{
            fx:viewportWidth*focalScale, fy:viewportWidth*focalScale,
            f:Math.min(viewportWidth,viewportHeight)/Math.PI,
            fovDegrees:180,tiltRadians:cameraTiltRadians
        })
        const region={x:c.cx-145,y:c.cy-60,width:290,height:120}
        const records=[], allGuides=[]
        for(let i=0;i<directionFamilies.length;i++) {
            const raw=directionFamilies[i], pair=Families.pair(raw)
            if(!pair.valid) {
                records.push({id:raw.id,valid:false,reason:pair.reason})
                continue
            }
            const vp=Projection.projectDirection(pair.direction3D,c)
            const opposite=Projection.projectDirection(pair.partnerDirection3D,c)
            const guides=Guides.projectFamily({
                id:raw.id,direction3D:pair.direction3D,
                guideOrigins:raw.guideOrigins
            },c,Projection)
            const anchors=[]
            for(const guide of guides) if(guide.segments.length) {
                const candidates=[]
                for(const segment of guide.segments)
                    for(const p of segment)
                        if(p.x>=region.x && p.x<=region.x+region.width
                           && p.y>=region.y && p.y<=region.y+region.height)
                            candidates.push(p)
                if(candidates.length)
                    anchors.push(candidates[Math.floor(candidates.length/2)])
            }
            const visibleCurves=[]
            for(const guide of guides) for(const segment of guide.segments) {
                const visible=segment.filter(p=>p.x>=0 && p.x<=c.width
                                             && p.y>=0 && p.y<=c.height)
                if(visible.length>=3) visibleCurves.push(visible)
            }
            const effective=c.model==="rectilinear"
                ? Guides.effectiveInfinity(vp,anchors,Math.hypot(region.width,region.height),
                                           angularToleranceRad,
                                           pixelTolerancePhysical,devicePixelRatio)
                : Guides.curveStraightness(visibleCurves,angularToleranceRad,
                                           pixelTolerancePhysical,devicePixelRatio)
            const record={id:raw.id,index:i,color:raw.color || "#fbbf24",
                direction3D:pair.direction3D,
                partnerDirection3D:pair.partnerDirection3D,
                primary:vp,partner:opposite,effective:effective,
                guides:guides,valid:true}
            records.push(record)
            for(const g of guides) allGuides.push({
                familyIndex:i,color:record.color,segments:g.segments
            })
        }
        return {revision:revision,presetKey:presetKey,config:c,evaluationRegionPx:region,
                families:records,guides:allGuides}
    }

    function applyPreset(key) {
        const fixture=Fixtures.preset(key)
        presetDescription=fixture.description
        fixtureProjection=fixture.projection
        projection=fixture.projection
        cameraTiltRadians=fixture.cameraTiltRadians || 0
        focalScale=fixture.focalScale || 0.33
        directionFamilies=fixture.families
    }
    function loadPreset(key) {
        if(presetKey===key) applyPreset(key)
        else presetKey=key
    }
    onPresetKeyChanged: applyPreset(presetKey)
    function moveDirection(index,partner,pixelX,pixelY) {
        pointerMoveCount++
        const d=Projection.inverseDirection({x:pixelX,y:pixelY},snapshot.config)
        if(!d || !directionFamilies[index]) return false
        const next=directionFamilies.slice()
        const old=next[index]
        next[index]={id:old.id,color:old.color,
                     direction3D:partner ? d.map(v=>-v) : d,
                     guideOrigins:old.guideOrigins}
        directionFamilies=next
        return true
    }
    function addFamily() {
        const next=directionFamilies.slice()
        const n=next.length+1
        next.push({id:"N"+n,direction3D:[0.37*n%1-0.5,0.23*n%1-0.5,1],
                   color:"#f9a8d4"})
        presetKey="N"
        directionFamilies=next
        presetDescription="Custom world-direction families"
    }
    function removeFamily(index) {
        if(index<0 || index>=directionFamilies.length) return false
        const next=directionFamilies.slice()
        next.splice(index,1)
        presetKey="N"
        directionFamilies=next
        presetDescription="Custom world-direction families"
        return true
    }
    Component.onCompleted: applyPreset(presetKey)
}
