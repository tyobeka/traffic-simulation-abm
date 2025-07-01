globals [
  white-car              ; selected car to watch
  lanes                  ; list of y coordinates of different lanes
  speed-limit            ; speed limit on the road
]

breed [ cars car ]
breed [ accidents accident ]
breed [ signs sign ]
breed [ cameras camera ]
breed [ detections detection]
breed [ potholes pothole ]
breed [ grass2 grass1 ]
breed [ flowers flower ]

cars-own [
  speed       ; the speed of a car (different for all cars)
  max-speed   ; the top speed of a car (different for all cars)
  patience    ; the current level of patience of driver (different for all drivers)
  target-lane ; the lane driver wants travel on
]

accidents-own [
  clear-in    ; how many ticks before an accident is cleared
]

to setup   ; to set up model without speed cameras
  clear-all

  ; shapes of objects in environment
  set-default-shape cars "car"
  set-default-shape accidents "fire"
  set-default-shape signs "warning"
  set-default-shape cameras "warning"
  set-default-shape detections "warning"
  set-default-shape potholes "circle"
  set-default-shape grass2 "square"
  set-default-shape flowers "flower"

  ; draw the road
  draw-road
  placing-cars

  ; setting speed limit
  set speed-limit 0.4

  ; placing warning sign, camera detection region and camera
  ask patch place-warning-sign (number-of-lanes + 1) [ sprout-signs 1 [
      set color orange ]
    ]

  ask patch (place-camera - 2) (number-of-lanes + 1) [ sprout-detections 1 [
      set color black ]
    ]

  ask patch place-camera (number-of-lanes + 1) [ sprout-cameras 1 [
      set color red]
    ]

  ; resetting ticks
  reset-ticks
end

to setup2 ; to set up model without speed cameras
  clear-all

  ; shapes of objects in environment
  set-default-shape cars "car"
  set-default-shape accidents "fire"
  set-default-shape potholes "circle"
  set-default-shape grass2 "square"
  set-default-shape flowers "flower"

  ; draw the road and place cars on road
  draw-road
  placing-cars

  ; setting speed limit
  set speed-limit 0.4

  ; resetting ticks
  reset-ticks
end

to placing-cars

  ; ensures that the number of cars on the road is less than or equal to number of patches of roads
  let street-patches patches with [ member? pycor lanes ]
  if number-of-cars > count street-patches [
    set number-of-cars count street-patches
  ]

  ; placing cars on the road
  create-cars (number-of-cars - count cars) [
    set color one-of base-colors
    move-to one-of free street-patches
    set target-lane pycor
    set heading 90
    set max-speed 0.2 + random-float 0.8
    set speed 0.2 + random-float speed-limit
  ]

  ; ensures that the number of cars on the road is never greater than the defined number-of-cars
  if count cars > number-of-cars [
    let n count cars - number-of-cars
    ask n-of n [ other cars ] of white-car [ die ]
  ]
end

to-report free [ street-patches ]

  ; report whether a patch has a car on it
  let this-car self
  report street-patches with [
    not any? cars-here with [ self != this-car ]
  ]
end

to draw-road

  ; draw grass
  ask patches [
    set pcolor green - random-float 0.5
  ]

  ; draw road
  set lanes n-values number-of-lanes [ n -> number-of-lanes - (n * 2) - 1 ]
  ask patches with [ abs pycor <= number-of-lanes ] [
    set pcolor grey - 2.5 + random-float 0.25
  ]

  ; draw lines white and yellow lines on road
  draw-road-lines

  ; draw sunflower bed :)
  draw-flowers


end

to draw-road-lines

  ; start with edge of bottom lane
  let road (last lanes) - 1

  ; ensures that yellow lines are drawn on each edge of the street, and dashed white line between lanes of the street
  while [ road <= first lanes + 1 ] [
    if not member? road lanes [
      ifelse abs road = number-of-lanes
      [ draw-line road yellow 0 ]
      [ draw-line road white 0.5 ]
    ]
    set road road + 1     ; move up
  ]
end

to draw-flowers

  ask patches [
    let rand random 2
    if pycor > (number-of-lanes + 1) and rand = 1 [ sprout-flowers 1 [
      set color yellow - random-float 0.5
      set size 1.5 ]
  ] ]

  ask patches [
    let rand random 2
    if pycor <= (-1 - number-of-lanes) and rand = 1 [ sprout-flowers 1 [
      set color yellow - random-float 0.5
      set size 1.5 ]
  ] ]

end

to draw-line [ road color-of-line line-type ]

  ; a turtle is used to draw the lines:
  ; if line-type is 0.5, we get a dashed line
  ; if line-type is 0, we get a continuous line
  create-turtles 1 [
    setxy (min-pxcor - 0.5) road
    hide-turtle
    set heading 90
    set color color-of-line
    repeat world-width [
      pen-up
      forward line-type
      pen-down
      fd (1 - line-type)
    ]
    die
  ]
end

to go

  ; 1. place cars on the road so that number of cars on the road is the same at the start of each tick
  ; 2. car move forward
  ; 3. check for accidents
  ; 4. car chooses a lane - stay on current lane, or move to new lane
  ; 5. car moves to desired lane

  placing-cars
  ask cars [ move-forward ]
  check-for-accidents

  ask cars with [ patience <= max-patience-before-lane-change ] [ choose-lane ]
  ask cars with [ ycor != target-lane ] [ move-to-desired-lane ]
  tick
end




to move-forward ; turtle procedure

  set heading 90   ; setting direction to travel in
  increase-speed   ; increase speed moving forward


  ; is there a pothole directly ahead
  let potholes-ahead potholes in-cone (1 + speed ) 180 with [ y-dist <= 1 ]
  let pothole-ahead min-one-of potholes-ahead [ distance myself ]

  ; is there an accident directly ahead
  let accidents-ahead accidents in-cone (1 + speed ) 180 with [ y-dist <= 1 ]
  let accident-ahead min-one-of accidents-ahead [ distance myself ]

  ; if there is a car ahead, you may need to slow down the car
  let cars-ahead other cars in-cone (1 + speed) 180 with [ y-dist <= 1 ]
  let car-ahead min-one-of cars-ahead [ distance myself ] ; car-ahead is the car closest from current car

  ; if there is a car ahead and you are travelling at the speed limit or below, reduce speed to match car ahead with some probability
  ; if there is a car ahead and you are travelling above the speed limit, then you are able to reduce speed with some probability
  if car-ahead != nobody and speed <= speed-limit  [
    let p random-float 1
    ifelse p <= when-obeying-speed-limit [
      set speed [ speed ] of car-ahead
    decrease-speed] [ decrease-speed ]
  ]

  if car-ahead != nobody and speed > speed-limit [
    let p random-float 1
    ifelse p <= when-disobeying-speed-limit [
      set speed [ speed ] of car-ahead
    decrease-speed] [ decrease-speed ]
  ]

  ; decrease speed when approach warning sign of speed trap ahead ifyou're travelling above the speed limit
  if pxcor >= (place-warning-sign - 2) and pxcor < place-camera  and speed > speed-limit [ decrease-speed ]

  ; speed of car is detected by camera, if you're travelling above the speed limit penalise car
  if pxcor = (place-camera - 2) and speed > speed-limit [
    set max-speed max-speed - 0.05
    if max-speed <= speed-limit [ set max-speed speed-limit + random-float 0.1 ]]


  ; if there is an accident ahead decrease speed, and lose patience so that you can change lanes
  if car-ahead = nobody and accident-ahead != nobody [
    decrease-speed
    set patience max-patience-before-lane-change ]

  ; if there is a pothole ahead stop the car
  if car-ahead = nobody and pothole-ahead != nobody [
    set speed 0]

  if speed = 0  [ set patience max-patience-before-lane-change ] ; if your speed is zero, lose patience and change lanes (you may be stuck behind a pothole or you may be stuck behind someone who stuck behind a pothole)

  forward speed
end


to decrease-speed ; turtle procedure

  ; how car decreases speed is dependent on rate of deceleration
  set speed (speed - deceleration)
  if speed <= 0 [ set speed deceleration ] ; speed can't be negative, decrease-speed turtle should not result in people coming to a complete halt

  set patience patience - 1 ; driver loses patience if they have to hit the brakes
end

to increase-speed ; turtle procedure

  ; how car increases speed is dependent on rate of acceleration
  set speed (speed + acceleration)

  ; ensures that driver can't exceed cars maximum car speed
  if speed > max-speed [ set speed max-speed ]
end


to check-for-accidents ; turtle procedure

  ; counter
  ask accidents [
    set clear-in clear-in - 1
    if clear-in = 0 [ die ]
  ]

  ; if there is more than one car on a patch then you cause an accident
  ask patches with [ count cars-here > 1 ] [
    sprout-accidents 1 [
      set size 1
      set color yellow
     set clear-in clear-accident
   ]
    ask cars-here [ die ]
  ]

  ; if you drive into accident you cause an even bigger accident
  ask patches with [ count accidents-here >= 1 and count cars-here >= 1 ] [
   sprout-accidents 1 [
      set size 1.5
      set color orange
      set clear-in clear-accident
   ]
    ask cars-here [ die ]
  ]
end

to choose-lane
  ; if there are two or more lanes on the street:
  ; driver can either move to lane on the left or right of it, if lanes are available
  ; i.e. new lane with the minimum distance to current lane (ycor)

  let remainder-lanes remove ycor lanes
  if not empty? remainder-lanes [
    let shortest-dist min map [ y -> abs (y - ycor) ] remainder-lanes
    let closest-lanes filter [ y -> abs (y - ycor) = shortest-dist ] remainder-lanes
    set target-lane one-of closest-lanes
    set patience 1 + random 100
  ]
end

to move-to-desired-lane

  set heading ifelse-value target-lane < ycor [ 180 ] [ 0 ] ; 180 = right lane, 0 = left lane

  ; is there a car next to you?
  let cars-beside other cars in-cone (1 + abs (ycor - target-lane)) 180 with [ x-dist <= 1 ]
  let car-beside min-one-of cars-beside [ distance myself ]

  ; how you are going to change lanes in there is next to you or not
  ifelse car-beside = nobody [
    forward 0.2
    set ycor precision ycor 1 ; to avoid floating point errors
  ] [
    ; slow down if the car blocking us is behind, otherwise speed up
    ifelse towards car-beside <= 180 [ decrease-speed ] [ increase-speed ]
  ]

end

; x coordinate of turtle
to-report x-dist
  report distancexy [ xcor ] of myself ycor
end

; y coordinate of turtle
to-report y-dist
report distancexy xcor [ ycor ] of myself
end


; selecting a car
to choose-car

  ; allow the user to select a different car by clicking on it with the mouse
  if mouse-down? [
    let mx mouse-xcor
    let my mouse-ycor
    if any? cars-on patch mx my [
      set white-car one-of cars-on patch mx my
      ask white-car [
        set color white
        set speed initial-speed
        set max-speed 1
      ]
      watch white-car
      display
    ]
  ]
end

; placing obstructions on the road
to choose-potholes
  ; allow the user to place the potholes by clicking on it with the mouse
  if mouse-down? [
    let mx mouse-xcor
    let my mouse-ycor
    ask patch mx my [sprout-potholes 1 [
      set color black
      set size 1 ]]
    display
    ]

end


to-report distance-between-warning-sign-and-camera
  report place-camera - place-warning-sign
end
@#$#@#$#@
GRAPHICS-WINDOW
4
308
1472
657
-1
-1
20.0
1
10
1
1
1
0
1
1
1
-36
36
-8
8
0
0
1
ticks
30.0

BUTTON
4
10
136
43
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
2
120
171
153
number-of-cars
number-of-cars
1
200
60.0
1
1
NIL
HORIZONTAL

SLIDER
2
160
174
193
number-of-lanes
number-of-lanes
1
6
2.0
1
1
NIL
HORIZONTAL

SLIDER
3
200
175
233
acceleration
acceleration
0.001
0.01
0.005
0.001
1
NIL
HORIZONTAL

SLIDER
1
240
173
273
deceleration
deceleration
0.01
0.1
0.02
0.01
1
NIL
HORIZONTAL

BUTTON
227
12
360
45
select-car
choose-car
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
144
46
220
79
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
675
11
934
212
Car Speeds
Time
Speed
0.0
300.0
0.0
0.5
true
true
"" ""
PENS
"average" 1.0 0 -11085214 true "" "plot mean [ speed ] of cars"
"max" 1.0 0 -2674135 true "" "plot max [ speed ] of cars"
"min" 1.0 0 -13345367 true "" "plot min [ speed ] of cars"
"speed limit" 1.0 0 -7500403 true "" "plot speed-limit"
"selected car" 1.0 0 -1184463 true "" "plot [ speed ] of white-car"

MONITOR
754
255
877
300
selected car speed
[ speed ] of white-car
3
1
11

PLOT
939
10
1193
211
Number of Cars Exceeding Speed Limit
Time
Number of Cars
0.0
300.0
0.0
20.0
true
true
"" ""
PENS
"fast cars" 1.0 0 -2674135 true "" "plot count cars with [ speed > speed-limit ]"
"total cars" 1.0 0 -7500403 true "" "plot number-of-cars"

BUTTON
227
47
360
80
place-obstructions
choose-potholes
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
177
240
349
273
initial-speed
initial-speed
0.1
1
0.6
0.1
1
NIL
HORIZONTAL

BUTTON
143
10
220
43
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1068
253
1325
298
NIL
distance-between-warning-sign-and-camera
3
1
11

TEXTBOX
782
146
932
164
NIL
11
0.0
1

PLOT
1197
10
1438
211
Number of Accidents
Time
Number of Accidents
0.0
300.0
0.0
10.0
true
true
"" ""
PENS
"accidents" 1.0 0 -2674135 true "" "plot count accidents"

SLIDER
176
122
348
155
place-warning-sign
place-warning-sign
-35
35
-20.0
1
1
NIL
HORIZONTAL

SLIDER
176
161
348
194
place-camera
place-camera
-35
35
-16.0
1
1
NIL
HORIZONTAL

BUTTON
4
46
137
79
setup (no camera)
setup2
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
352
200
558
233
when-obeying-speed-limit
when-obeying-speed-limit
0
1
0.95
0.05
1
NIL
HORIZONTAL

SLIDER
352
241
558
274
when-disobeying-speed-limit
when-disobeying-speed-limit
0
1
0.85
0.05
1
NIL
HORIZONTAL

SLIDER
354
161
558
194
clear-accident
clear-accident
1
1000
5.0
1
1
NIL
HORIZONTAL

SLIDER
353
122
558
155
max-patience-before-lane-change
max-patience-before-lane-change
0
50
30.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

There is evidence to suggest that there exists a statistical relationship between road safety and speed. By reducing the mean speed of cars travelling on a road, a reduction in the number of accidents and severity of injuries caused is most likely to be observed; and similarly, by increasing the mean speed of cars travelling on a road, an increase in the number of accidents and severity of injuries caused is most likely to occur.

A number of measures are employed by law enforcement to reduce the mean speed of traffic. These measures include the use of speed zoning and speed limits, regulating and enforcing speed limits (e.g. fines, speed cameras, road-blocks), engineering treatments (e.g. speed-bumps, traffic lights, roundabouts), public education, and speed-limiting technology and intelligent speed adaptation (e.g. speed limiter and traffic data being made available on GPS devices). 

This model looks at the effectiveness of speed cameras in changing the behaviour of road users, and in the process reducing the number of accidents which occur on a road where a speed limit is being employed. It assumes that cars enter the road having already seen the sign indicating a speed limit. Each car follows a set of rules. It accelarates if there is no car ahead, and decelerates if it sees a car close ahead. Depending on the driver, the car's speed may or may not comply with the speed limit. 

The user is able to compare patterns in traffic behaviour with or without speed cameras; with fixed or mobile speed cameras; and in the case of fixed speed cameras whether the distance between sign warning drivers of the speed camera ahead and the speed camera itself is significant when setting up speed cameras on a road. 

The user is also able to adjust conditions which affect the driver's ability to get from point A to point B such as rate of acceleration and deceleration, the probability that a car is able to reduce its speed successfully when approaching a car ahead which may vary depending on weather, conditions of the road, possible faults in a car, or whether a driver is negligent.

## HOW IT WORKS

A road is set up with a user-defined number of lanes. Speed cameras and their corresponding warning signs are found on the side of the road. Cars are then randomly placed on the road with random initial speeds. Car are then allowed to travel to end of the road based on the following rules:

- A car enter the road at some random speed between half the speed limit and 1.5 times the speed limit. 

- It can only move forward.

-  The speed of a car increases if there is no obstruction directly ahead (i.e. another car, an accident, or a section of the road which has been blocked off such as a pothole or roadwork) or if there is no speed camera near by. The increase in speed is dependent on a acceleration rate which is assumed to be the same for every car. 

- A maximum speed a driver is willing to travel with on the road is defined randomly for each car. The lower the value, the more risk averse the individual is. Any increase in speed cannot exceed this maximum.

- The speed of a car is decreased if there is an obstruction ahead, or if there is speed camera ahead. In the case that there is car directly ahead, the car will reduce its speed so as to match the speed of the car ahead. The car's ability to reduce its speed in this case is dependent on some probability. 

- Once a car spots a warning sign flagging drivers that speed camera lies ahead, the car will attempt to reduce its speed to adhere with the speed limit. Between the sign warning drivers of a speed camera ahead and the speed camera itself, if the car is travelling above the speed limit, it will attempt to reduce its speed so as to adhere to the speed limit. If the car is driving within the speed limit, it may increase its speed, provided that the increase does not result in it exceeding the speed limit.

- If the car is travelling above the speed limit once it approaches the detection range of the speed camera, the maximum speed of the car is reduced - the driver becomes more risk averse (i.e. they have received a fine, so now they are more cautious the next time they enter the road). 

- If a car fails to reduce its to match the speed of a the car directly ahead when approaching, an accident occurs.

- Every time the car has to reduce its speed, the driver loses patience. At some MAXIMUM-PATIENCE-BEFORE-CHANGING-LANES (defined by the user of the model), the driver will attempt to change lanes. The patience of each driver differs.

- If a car approaches an accident directly ahead, the driver will attempt to change lanes.

- If a section of the road is blocked off, the driver is forced to come to a halt, since they cannot drive over it, when an opportunity arises the driver will attempt to change lanes.

- When a car accidents occur, the cars involved are removed from the model and new cars are allowed to enter the model.

Cars are allowed to re-enter the road after reaching the end. The speed at which they re-enter the road is the same speed that they exited the road with. In so doing, we are able to see if the speed cameras have a temporary affect on road user behaviour, or if this affect is long-lasting.

To further observe the effectiveness of speed cameras, users of this model can run it with or without speed cameras by selecting the SETUP or SETUP (without camera) button, respectively. The user can adjust the distance between the warning sign flagging driver of a speed camera and the speed camera to find an effective distance. By placing the warning sign in the same position as the speed camera, this can act as a mobile speed camera. 

## HOW TO USE IT

Click on the SETUP button to set up the cars with the speed camera and its warning sign. Click on the SETUP (without camera) button to set up the cars without the speed camera. Click on the GO button to start the cars moving. The GO ONCE button moves the cars for one tick of the clock.

The SELECT-CAR button lets the user choose a car to focus on.

The PLACE-OBSTRUCTIONS button lets the user place an obstruction on the road. This obstruction could be a pothole in the road, road work being done, etc.

The INITIAL-SPEED slider controls the initial speed which the selected car enters the road with.

The NUMBER-OF-CARS slider controls the number of cars on the road at every tick. If a car is removed from the road as a result of having been involved in an accident, a car will be added. If the value on the slider is changed whilst the model is running, cars will be added or removed immediately to reflect the new value.

The NUMBER-OF-LANES slider controls the number of lanes on the road at every tick. The number of lanes on the road can only be changed when one re-sets the model.

The ACCELERATE slider controls the amount a car can increase its speed by at each tick.

The DECELERATE slider controls the amount a car can decrease its speed by at each tick.

The MAX-PATIENCE-BEFORE-LANE-CHANGE slider controls the maximum patience of a driver before they lose patience and try to change lanes. 

The PLACE-WARNING-SIGN slider controls where along the road one wants to place the sign warning cars that a speed camera lies ahead.

The PLACE-CAMERA slider controls where along the road one wants to place the speed camera.

The WHEN-OBEYING-SPEED-LIMIT slider controls when a car is driving within the speed limit: when approaching a car ahead what is the probability that the car is able to decrease its speed to match the speed the of the car ahead.

The WHEN-DISOBEYING-SPEED-LIMIT slider controls when a car is driving above the speed limit: when approaching a car ahead what is the probability that the car is able to decrease its speed to match the speed the of the car ahead.

The CLEAR-IN slider controls how many ticks occur before an accident is cleared from the road.

The interface displays three plots: the speed of cars at each tick, the number of cars exceeding the speed limit at each tick, and the number of accidents which occur at each tick. Further, one can observe the speed of the selected car at each tick, as well as the distance between the speed camera and its warning sign.


## THINGS TO NOTICE

When there is a high deceleration rate and low acceleration, we see a drastic increase in number of accidents and increased severity (i.e. more than two cars involved in a single accident). Similarly, when there is high acceleration and low deceleration, we see a drastic increase in number of accidents and increased severity. In the case of high acceleration and low deceleration, cars travelling at higher speed don't have enough time to reduce their speed and end up colliding with cars directly ahead. Further, cars approaching the accident scene don't have enough time to reduce speed, which results in the increased severity of accidents. In the case of low acceleration and high deceleration, at first glance one may think this shouldn't be a much of a problem. If a car is decelerating, it almost appears as a random halt for the car behind which causes accidents.

If the cars leading the traffic in each lane are travelling at very low speeds over time, because there is no room to overtake these cars, the remaining cars are forced to follow suite. It is not realistic that all lanes would be lead by slow drivers. How can this be adjusted so that there are slower lanes on one side and faster lanes on the other? 

When there is a large number of cars on the road and traffic starts to form, drivers lose patience much more quick and move in and out between lanes. Further, there is a large number of accidents in this setting. This is not very realistic. The large number of accidents is as a result of cars being introduced to the model with different initial speeds, because there are so many cars on the road, there isn't enough time to reduce one's speed to match the speed of a car ahead. This is further worsened by the constant changing of lanes. It would worth investigating whether adjusting the MAX-PATIENCE-BEFORE-LANE-CHANGE aids the problem.  

When there are no speed cameras on the road: a plot of the average, minimum and maximum speed of cars is given at each tick. When is there is a fairly large number of cars on the road, the average speed of cars tends to fluctuate around the speed limit or it decreases. When there are barely any cars on the road, the average speed of cars on the road is either above the speed-limit, or it fluctuates around the speed limit, or it is less than speed limit. The average speed of cars on the road is clearly dependent on the risk profiles of the drivers. The more risk averse (i.e. the low levels of MAX-SPEED) they are, lower the average speed.

When there is a speed camera on the road: whether there is a large number of cars on the road or a few, the plot of the average car speeds appears to reflect a similar pattern, i.e. the average speed of cars tends to fluctuate around the speed limit or it decreases. This is as result of drivers becoming more risk averse when the speed trap detects these individuals travelling at high speeds. The plot of the maximum speed of cars at each tick does not always converge, especially when there are regular accidents occuring on the road. This is as a result of the new cars being introduced into the model. If the drivers of these cars are risk-takers, these cars only begin adjust their speed when exposed to a camera or in some cases these cars adjust to average speed of the traffic if the flow is more stable.

It is worth noting how cars are penalised for driving at above the speed when there are speed cameras on the road: if a car is travelling above the speed limit within the camera detection range, the MAX-SPEED of the car is decreased. This is meant to represent a driver receiving a penalty for driving recklessly, therefore resulting in the driver being a little more cautious the next time they re-enter the model. Hence, the model is able to modify the behaviour of drivers.

It is hard to tell what the significance of certain placements of the speed camera has in reducing the mean speed of traffic, this requires further investigation in BehaviorSpace.


## THINGS TO TRY

- The implementation of speed cameras on the roads can be a costly venture, with respect to time, finance and state resources. Would including another sign on this road reminding drivers of the speed limit have any affect on the mean speed of traffic?  Maybe some people did not see the previous sign or have forgotten what the speed limit on this road is? 

- Putting the warning sign alerting cars of the speed camera ahead in the same position as the speed camera. This can serve as random mobile speed trap. How does this affect driver behaviour?

- Increasing the number of decimal places in the WHEN-OBEYING-SPEED-LIMIT and WHEN-DISOBEYING-SPEED-LIMIT sliders and adjusting these values. Does this influence the number of accidents seen on the road? Does this reflect more realistic behaviours?

- Assigning individual acceleration and deceleration values to each car. Would it be more suitable for the assignment to be random or should one also consider driver behaviour? For example a lot of risk-takers on the road drive fancy cars with high acceleration rates.  

- If an accident occurs, use the PLACE-OBSTRUCTIONS button to block off that section of the road to mimic the behaviour of police and paramedic coming to investigate and clear off the road. Include a button to remove the potholes over time. How do the car adjust the behaviour when the lanes are opened up again?

- When we have high acceleration and low deceleration, what kind of road does this mimic? Going down a hill, perhaps? What a low acceleration, and high deceleration? Going up a hill? In the second case, one would probably have to allow the car to roll backwards with some probability to account for those who are inexperienced in driving on such roads.


## EXTENDING THE MODEL


- Assigning a fast and slow lanes on roads with with more than one lane.

- If the road only has one lane, allow cars travelling at a slow speed resulting in traffic slowly forming to move to the side of the road, to allow other cars to overtake.

- Are the WHEN-OBEYING-SPEED-LIMIT and WHEN-DISOBEYING-SPEED-LIMIT probabilities too general? These probabilities take into consideration current speed, state of roads, driver negligence, etc. and how this may influence a driver's ability to reduce its speed in time. Can all these different factors be taken into consideration separately?

- Introducing sharp bends in the road, or a snaking road where travelling at high speeds is not recommended.

- Are drivers always either risk-takers or risk averse? How can the model be adjusted the model to reflect that sometimes an individual who would normally follow the rules may be risk-taker on one day because they are rushing for a meeting?
 

## RELATED MODELS

- “Traffic Basic”: a simple model of the movement of cars on a highway.

- "Traffic 2 Lanes": a more sophisticated two-lane version of the “Traffic Basic” model.

- “Traffic Basic Utility”: a version of “Traffic Basic” including a utility function for the cars.

- “Traffic Basic Adaptive”: a version of “Traffic Basic” where cars adapt their acceleration to try and maintain a smooth flow of traffic.

- “Traffic Basic Adaptive Individuals”: a version of “Traffic Basic Adaptive” where each car adapts individually, instead of all cars adapting in unison.

- “Traffic Intersection”: a model of cars traveling through a single intersection.

- “Traffic Grid”: a model of traffic moving in a city grid, with stoplights at the intersections.

- “Traffic Grid Goal”: a version of “Traffic Grid” where the cars have goals, namely to drive to and from work.

- “Gridlock HubNet”: a version of “Traffic Grid” where students control traffic lights in real-time.

- “Gridlock Alternate HubNet”: a version of “Gridlock HubNet” where students can enter NetLogo code to plot custom metrics.


## REFERENCES

- Wilensky, U. (1997). NetLogo Traffic Basic model. http://ccl.northwestern.edu/netlogo/models/TrafficBasic. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

- Wilensky, U. & Payette, N. (1998). NetLogo Traffic 2 Lanes model. http://ccl.northwestern.edu/netlogo/models/Traffic2Lanes. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

- Joubert, Johan. “Science & Speed Camera Enforcement.” Arrive Alive, www.arrivealive.co.za/Science-Speed-Camera-Enforcement#:~:text=Speed%20cameras%20work%20to%20reduce. Accessed 20 Sept. 2020.

- World Health Organisation. What Are the Tools for Managing Speed?, https://www.who.int/roadsafety/projects/manuals/speed_manual/3-What.pdf. Accessed 20 Sept. 2020.

‌
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

emblem
false
0
Polygon -7500403 true true 0 90 15 120 285 120 300 90
Polygon -7500403 true true 30 135 45 165 255 165 270 135
Polygon -7500403 true true 60 180 75 210 225 210 240 180
Polygon -7500403 true true 150 285 15 45 285 45
Polygon -16777216 true false 75 75 150 210 225 75

exclamation
false
0
Circle -7500403 true true 103 198 95
Polygon -7500403 true true 135 180 165 180 210 30 180 0 120 0 90 30

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fire
false
0
Polygon -7500403 true true 151 286 134 282 103 282 59 248 40 210 32 157 37 108 68 146 71 109 83 72 111 27 127 55 148 11 167 41 180 112 195 57 217 91 226 126 227 203 256 156 256 201 238 263 213 278 183 281
Polygon -955883 true false 126 284 91 251 85 212 91 168 103 132 118 153 125 181 135 141 151 96 185 161 195 203 193 253 164 286
Polygon -2674135 true false 155 284 172 268 172 243 162 224 148 201 130 233 131 260 135 282

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

house bungalow
false
0
Rectangle -7500403 true true 210 75 225 255
Rectangle -7500403 true true 90 135 210 255
Rectangle -16777216 true false 165 195 195 255
Line -16777216 false 210 135 210 255
Rectangle -16777216 true false 105 202 135 240
Polygon -7500403 true true 225 150 75 150 150 75
Line -16777216 false 75 150 225 150
Line -16777216 false 195 120 225 150
Polygon -16777216 false false 165 195 150 195 180 165 210 195
Rectangle -16777216 true false 135 105 165 135

house colonial
false
0
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 45 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 60 195 105 240
Rectangle -16777216 true false 60 150 105 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Polygon -7500403 true true 30 135 285 135 240 90 75 90
Line -16777216 false 30 135 285 135
Line -16777216 false 255 105 285 135
Line -7500403 true 154 195 154 255
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 135 150 180 180

house efficiency
false
0
Rectangle -7500403 true true 180 90 195 195
Rectangle -7500403 true true 90 165 210 255
Rectangle -16777216 true false 165 195 195 255
Rectangle -16777216 true false 105 202 135 240
Polygon -7500403 true true 225 165 75 165 150 90
Line -16777216 false 75 165 225 165

house ranch
false
0
Rectangle -7500403 true true 270 120 285 255
Rectangle -7500403 true true 15 180 270 255
Polygon -7500403 true true 0 180 300 180 240 135 60 135 0 180
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 45 195 105 240
Rectangle -16777216 true false 195 195 255 240
Line -7500403 true 75 195 75 240
Line -7500403 true 225 195 225 240
Line -16777216 false 270 180 270 255
Line -16777216 false 0 180 300 180

house two story
false
0
Polygon -7500403 true true 2 180 227 180 152 150 32 150
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 75 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 90 150 135 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Rectangle -7500403 true true 15 180 75 255
Polygon -7500403 true true 60 135 285 135 240 90 105 90
Line -16777216 false 75 135 75 180
Rectangle -16777216 true false 30 195 93 240
Line -16777216 false 60 135 285 135
Line -16777216 false 255 105 285 135
Line -16777216 false 0 180 75 180
Line -7500403 true 60 195 60 240
Line -7500403 true 154 195 154 255

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tile stones
false
0
Polygon -7500403 true true 0 240 45 195 75 180 90 165 90 135 45 120 0 135
Polygon -7500403 true true 300 240 285 210 270 180 270 150 300 135 300 225
Polygon -7500403 true true 225 300 240 270 270 255 285 255 300 285 300 300
Polygon -7500403 true true 0 285 30 300 0 300
Polygon -7500403 true true 225 0 210 15 210 30 255 60 285 45 300 30 300 0
Polygon -7500403 true true 0 30 30 0 0 0
Polygon -7500403 true true 15 30 75 0 180 0 195 30 225 60 210 90 135 60 45 60
Polygon -7500403 true true 0 105 30 105 75 120 105 105 90 75 45 75 0 60
Polygon -7500403 true true 300 60 240 75 255 105 285 120 300 105
Polygon -7500403 true true 120 75 120 105 105 135 105 165 165 150 240 150 255 135 240 105 210 105 180 90 150 75
Polygon -7500403 true true 75 300 135 285 195 300
Polygon -7500403 true true 30 285 75 285 120 270 150 270 150 210 90 195 60 210 15 255
Polygon -7500403 true true 180 285 240 255 255 225 255 195 240 165 195 165 150 165 135 195 165 210 165 255

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

tree pine
false
0
Rectangle -6459832 true false 120 225 180 300
Polygon -7500403 true true 150 240 240 270 150 135 60 270
Polygon -7500403 true true 150 75 75 210 150 195 225 210
Polygon -7500403 true true 150 7 90 157 150 142 210 157 150 7

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

warning
false
0
Polygon -7500403 true true 0 240 15 270 285 270 300 240 165 15 135 15
Polygon -16777216 true false 180 75 120 75 135 180 165 180
Circle -16777216 true false 129 204 42

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-13"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="47"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final no camera" repetitions="100" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>count accidents</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="5"/>
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final no camera 1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count accidents</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final no camera 2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>mean [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final no camera 3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>max [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final camera" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count cars with [ speed &gt; speed-limit ]</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-15"/>
      <value value="-10"/>
      <value value="-4"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final camera 1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count accidents</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-15"/>
      <value value="-10"/>
      <value value="-4"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final camera 2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>mean [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-15"/>
      <value value="-10"/>
      <value value="-4"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final camera 3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>mean [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="-16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="camerassss" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count cars with [ speed &gt; speed-limit ]</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-30"/>
      <value value="-10"/>
      <value value="8"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="camerassss2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>mean [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-30"/>
      <value value="-10"/>
      <value value="8"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="camerassss3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>max [ speed ] of cars</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-camera">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="place-warning-sign">
      <value value="-30"/>
      <value value="-10"/>
      <value value="8"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="100" runMetricsEveryStep="true">
    <setup>setup2</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count accidents</metric>
    <enumeratedValueSet variable="number-of-lanes">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-accident">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="acceleration">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-obeying-speed-limit">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-cars">
      <value value="30"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="when-disobeying-speed-limit">
      <value value="0.85"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deceleration">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-patience-before-lane-change">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
