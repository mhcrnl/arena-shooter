Game = class("Game", PhysicalWorld):include(MessageEnabled)

function Game:initialize(designFunc, width, height)
  PhysicalWorld.initialize(self, 0, 0)
  self:setupMessages()
  love.physics.setMeter(50)
  
  self.width = width or 1680
  self.height = height or 1050
  self.paused = false
  self.over = false
  self.deltaFactor = 1
  Game.static.id = self

  self.maxSlowmo = 2
  self.slowmoFactor = 0.25
  self.slowmoRecharge = 0.2
  self.slowmo = self.maxSlowmo
  self.slowmoActive = false
  
  self.camera = GameCamera:new()
  self.score = ScoreTracker:new()
  self.fade = Fade:new(0.5, true)
  self.hud = HUD:new()
  self.player = Player:new(50, self.height / 2)
  self.background = Background:new()
  
  self:setupLayers{
    postfx.include,
    [-2] = 0, -- fade
    [-1] = 0, -- HUD
    [0] = 1, -- in-world HUD
    postfx.exclude,
    [1] = 1, -- barrier
    [2] = 1, -- player
    [3] = 1, -- enemy
    [4] = 1, -- missile
    [5] = 1, -- particles
    [6] = 1 -- background
  }
  
  self:add(self.score, self.fade, self.hud, self.player)
  designFunc = designFunc or self.defaultSetup
  designFunc(self, self.width, self.height)
  self:add(self.background)
end

function Game:defaultSetup(width, height)
  local padding = 40
  self.player.x = width / 2
  self.player.y = padding
  
  self:add(
    ExternalBarrier:new(),
    InternalBarrier:new("rectangle", width / 2, height / 2, width / 4, height / 4),
    EnemySpawner:new(padding, padding),
    EnemySpawner:new(width - padding, padding),
    EnemySpawner:new(padding, height - padding),
    EnemySpawner:new(width - padding, height - padding)
  )
end

function Game:start()
  self.fade:fadeIn()
end

function Game:update(dt)
  if input.pressed("pause") then self:pause() end
  if self.paused then return end
  
  if not self.over then
    if self.slowmoActive then
      self.slowmo = self.slowmo - dt
      
      if self.slowmo <= 0 or input.released("slowmo") then
        if self.slowmoTween then self.slowmoTween:stop() end
        self.slowmoTween = tween(self, 0.15, { deltaFactor = 1 })
        self.slowmoActive = false
      end
    else
      if self.slowmo < self.maxSlowmo then
        self.slowmo = math.min(self.slowmo + self.slowmoRecharge * dt, self.maxSlowmo)
      end
      
      if self.slowmo > 0 and input.pressed("slowmo") then
        if self.slowmoTween then self.slowmoTween:stop() end
        self.slowmoTween = tween(self, 0.15, { deltaFactor = self.slowmoFactor })
        self.slowmoActive = true
        self.player:showSlowmo()
      end
    end
  elseif self.canReset and input.pressed("reset") then
    self.fade:fadeOut(self.reset, self)
  end
  
  dt = dt * self.deltaFactor
  _G.dt = dt
  postfx.update(dt)
  PhysicalWorld.update(self, dt)
  if key.pressed.k then self.player:die() end
end

function Game:draw()
  postfx.start()
  PhysicalWorld.draw(self)
  postfx.stop()
end

function Game:gameOver()
  if self.slowmoTween then self.slowmoTween:stop() end
  self.slowmoTween = tween(self, 0.25, { deltaFactor = 0.1 }, nil, self.stopGameOverSlowmo, self)
  self.over = true
  self.hud.drawCursor = false
end

function Game:resolutionChanged()
  self.camera:update()
  self.hud:adjustText()
  self.background:resize()
end

function Game:pause()
  if not PauseMenu.id then PauseMenu:new() end
  ammo.world = PauseMenu.id
  self.paused = true
end

function Game:unpause()
  ammo.world = self
  self.paused = false
end

function Game:reset()
  ammo.world = Game:new() -- quick, temporary way of doing it
end

function Game:stopGameOverSlowmo()
  self.slowmoTween = tween(self, "0.2:0.3", { deltaFactor = 1 }, nil, self.gameOverSlowmoStopped, self)
end

function Game:gameOverSlowmoStopped()
  self.canReset = true
  data.score(self.score.score)
  self.hud:gameOver()
end
