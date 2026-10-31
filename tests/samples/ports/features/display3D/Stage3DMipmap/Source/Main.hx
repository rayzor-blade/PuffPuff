package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.display3D.textures.Texture;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.Context3DMipFilter;
import openfl.display3D.Context3DTextureFilter;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.Context3DWrapMode;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.Program3D;
import openfl.display3D.VertexBuffer3D;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.geom.Matrix;
import openfl.geom.Matrix3D;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;
import openfl.ui.Keyboard;
import openfl.utils.Timer;
import openfl.Assets;
import openfl.Lib;
import openfl.Vector;

class Main extends Sprite
{
	private static var DAMPING = 1.09;
	private static var LINEAR_ACCELERATION = 0.0005;
	private static var MAX_FORWARD_VELOCITY = 0.05;
	private static var MAX_ROTATION_VELOCITY = 0.5;
	private static var ROTATION_ACCELERATION = 0.01;

	private var cameraLinearAcceleration:Float;
	private var cameraLinearVelocity:Vector3D;
	private var cameraRotationAcceleration:Float;
	private var cameraRotationVelocity:Float;
	private var cameraWorldTransform:Matrix3D;
	private var context3D:Context3D;
	private var indexBuffer:IndexBuffer3D;
	private var program:Program3D;
	private var projectionTransform:PerspectiveMatrix3D;
	private var texture:Texture;
	private var vertexbuffer:VertexBuffer3D;
	private var viewTransform:Matrix3D;

	public function new()
	{
		super();

		stage.stage3Ds[0].addEventListener(Event.CONTEXT3D_CREATE, stage3D_onContext3DCreate);
		stage.stage3Ds[0].requestContext3D();

		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;

		addEventListener(Event.ENTER_FRAME, this_onEnterFrame);

		stage.addEventListener(KeyboardEvent.KEY_DOWN, stage_onKeyDown);
		stage.addEventListener(KeyboardEvent.KEY_UP, stage_onKeyUp);
	}

	private function calculateUpdatedVelocity(curVelocity:Float, curAcceleration:Float, maxVelocity:Float):Float
	{
		var newVelocity:Float;

		if (curAcceleration != 0)
		{
			newVelocity = curVelocity + curAcceleration;

			if (newVelocity > maxVelocity)
			{
				newVelocity = maxVelocity;
			}
			else if (newVelocity < -maxVelocity)
			{
				newVelocity = -maxVelocity;
			}
		}
		else
		{
			newVelocity = curVelocity / DAMPING;
		}

		return newVelocity;
	}

	private function initialize():Void
	{
		context3D = stage.stage3Ds[0].context3D;

		context3D.configureBackBuffer(800, 600, 1, true);

		var vertices = Vector.ofArray([-0.3, -0.3, 0, 0, 0, -0.3, 0.3, 0, 0, 1, 0.3, 0.3, 0, 1, 1, 0.3, -0.3, 0, 1, 0]);

		vertexbuffer = context3D.createVertexBuffer(4, 5);
		vertexbuffer.uploadFromVector(vertices, 0, 4);

		indexBuffer = context3D.createIndexBuffer(6);
		indexBuffer.uploadFromVector(Vector.ofArray([0, 1, 2, 2, 3, 0]), 0, 6);

		var bitmapData = Assets.getBitmapData("assets/checkers.png");
		texture = context3D.createTexture(bitmapData.width, bitmapData.height, Context3DTextureFormat.BGRA, false);
		uploadTextureWithMipMaps(texture, bitmapData);

		program = context3D.createProgram();
		program.uploadHXSL(TexturedShader);

		cameraWorldTransform = new Matrix3D();
		cameraWorldTransform.appendTranslation(0, 0, -2);
		viewTransform = new Matrix3D();
		viewTransform = cameraWorldTransform.clone();
		viewTransform.invert();

		cameraLinearVelocity = new Vector3D();
		cameraRotationVelocity = 0;

		cameraLinearAcceleration = 0;
		cameraRotationAcceleration = 0;

		projectionTransform = new PerspectiveMatrix3D();

		var aspect = 4 / 3;
		var zNear = 0.1;
		var zFar = 1000;
		var fov = 45 * Math.PI / 180;

		projectionTransform.perspectiveFieldOfViewLH(fov, aspect, zNear, zFar);
	}

	private function render():Void
	{
		if (context3D == null)
		{
			return;
		}

		context3D.clear(1, 1, 1, 1);
		context3D.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);

		context3D.setProgram(program);
		context3D.setVertexBufferAt(program.inputLocation("position"), vertexbuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
		context3D.setVertexBufferAt(program.inputLocation("uv"), vertexbuffer, 3, Context3DVertexBufferFormat.FLOAT_2);

		context3D.setTextureAt(program.textureSlot("image"), texture);
		// The AGAL program sampled <linear,nomip>; here the sampler blends the levels the sample uploads.
		context3D.setSamplerStateAt(program.textureSlot("image"), Context3DWrapMode.CLAMP, Context3DTextureFilter.LINEAR, Context3DMipFilter.MIPLINEAR);

		updateViewMatrix();

		var matrix = new Matrix3D();
		matrix.appendRotation(Lib.getTimer() / 30, Vector3D.Y_AXIS);
		matrix.appendRotation(Lib.getTimer() / 10, Vector3D.X_AXIS);
		matrix.appendTranslation(0, 0, -1);
		matrix.append(viewTransform);
		matrix.append(projectionTransform);

		program.setMatrixParameter("mvp", matrix);

		context3D.drawTriangles(indexBuffer);
		context3D.present();
	}

	private function updateViewMatrix():Void
	{
		cameraLinearVelocity.z = calculateUpdatedVelocity(cameraLinearVelocity.z, cameraLinearAcceleration, MAX_FORWARD_VELOCITY);
		cameraRotationVelocity = calculateUpdatedVelocity(cameraRotationVelocity, cameraRotationAcceleration, MAX_ROTATION_VELOCITY);

		cameraWorldTransform.appendRotation(cameraRotationVelocity, Vector3D.Y_AXIS, cameraWorldTransform.position);
		cameraWorldTransform.position = cameraWorldTransform.transformVector(cameraLinearVelocity);

		viewTransform.copyFrom(cameraWorldTransform);
		viewTransform.invert();
	}

	private function uploadTextureWithMipMaps(texture:Texture, originalImage:BitmapData):Void
	{
		var mipWidth = originalImage.width;
		var mipHeight = originalImage.height;
		var mipLevel = 0;
		var mipImage = new BitmapData(originalImage.width, originalImage.height);
		var scaleTransform = new Matrix();

		while (mipWidth > 0 && mipHeight > 0)
		{
			mipImage.draw(originalImage, scaleTransform, null, null, null, true);
			texture.uploadFromBitmapData(mipImage, mipLevel);
			scaleTransform.scale(0.5, 0.5);
			mipLevel++;
			mipWidth >>= 1;
			mipHeight >>= 1;
		}

		mipImage.dispose();
	}

	// Event Handlers

	private function stage_onKeyDown(event:KeyboardEvent):Void
	{
		switch (event.keyCode)
		{
			case Keyboard.LEFT:
				cameraRotationAcceleration = -ROTATION_ACCELERATION;

			case Keyboard.UP:
				cameraLinearAcceleration = LINEAR_ACCELERATION;

			case Keyboard.RIGHT:
				cameraRotationAcceleration = ROTATION_ACCELERATION;

			case Keyboard.DOWN:
				cameraLinearAcceleration = -LINEAR_ACCELERATION;
		}
	}

	private function stage_onKeyUp(event:KeyboardEvent):Void
	{
		switch (event.keyCode)
		{
			case Keyboard.LEFT, Keyboard.RIGHT:
				cameraRotationAcceleration = 0;

			case Keyboard.UP, Keyboard.DOWN:
				cameraLinearAcceleration = 0;
		}
	}

	private function stage3D_onContext3DCreate(event:Event):Void
	{
		initialize();
	}

	private function this_onEnterFrame(event:Event):Void
	{
		render();
	}
}
