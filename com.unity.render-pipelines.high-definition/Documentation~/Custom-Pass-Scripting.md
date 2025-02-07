# Scripting your own Custom Pass in C#

You can extend the CustomPass class in the Custom Pass API to create complex effects, such as a Custom Pass that has more than one buffer or uses [Compute Shaders](https://docs.unity3d.com/Manual/class-ComputeShader.html).

When you create your own C# Custom Pass using the instructions in [The Custom Pass C# Template](#Custom-Pass-C#-template), it automatically appears in the list of available Custom Passes in the Custom Pass Volume component.

<a name="Custom-Pass-C#-template"></a>

## **The Custom Pass C# template**

To create a new Custom pass, go to **Assets > Create > Rendering > HDRP C# Custom Pass**. This creates a new script that contains the Custom Pass C# template:

```C#
class #SCRIPTNAME# : CustomPass
{
    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd) {}

    protected override void Execute(CustomPassContext ctx) {}

    protected override void Cleanup() {}
}
```

The C# Custom Pass template includes the following entry points to code your custom pass:

| **Entry Point** | **Description**                                              |
| --------------- | ------------------------------------------------------------ |
| `Setup`         | Use this to allocate all the resources you need to render your pass, such as render textures, materials, and compute buffers. |
| `Execute`       | Use this to describe what HDRP renders during the Custom Pass. |
| `Cleanup`       | Use this to clear the resources you allocated in the Setup method .Make sure to include every allocated resource to avoid memory leaks. |

The `Setup` and `Execute` methods give you access to a `ScriptableRenderContext` and a `CommandBuffer`. For information on using `CommandBuffers` with a `ScriptableRenderContext`, see [Scheduling and executing commands in the Scriptable Render Pipeline](https://docs.unity3d.com/Manual/srp-using-scriptable-render-context.html).

## **Creating a full-screen Custom Pass in C#**

The following code demonstrates how to create a full-screen Custom Pass that applies an outline effect to an object in your scene.

![A mesh in a scene rendered using this outline effect](images/CustomPass_FrameDebugger.png)

This effect uses a transparent full screen pass with a blend mode that replaces the pixels around the GameObject you assign the script to.

This shader code performs the following steps:

1. Renders the objects in the outline layer to a buffer called `outlineBuffer`.
2. Samples the color in `outlineBuffer`. If the color is below the threshold, then it means that the pixel might be in an outline.
3. Searches neighboring pixels to check if this is the case.
4. If Unity finds a pixel above the threshold, it applies the outline effect.

<a name="Creating-Cusom-Pass-script"></a>

### Creating a CustomPass script

This section provides an example of a Custom Pass C# script that applies an outline effect to every GameObject in a Layer.

The following pass renders all the GameObjects in the `Outline Layer` into a custom buffer named `outlineBuffer` in the code. It then performs an edge detection algorithm over the screen that checks for all the GameObjects rendered in the `outlineBuffer`. This edge detection algorithm creates an outline around objects rendered in the `outlineBuffer`. Finally, `CoreUtils.DrawFullScreen` applies the full screen effect.

This example only supports a single outline color for all the objects in a Layer.

To use this example Custom Pass script:

1. Create a new C# script (menu: **Assets > Create > C# Script)**.
2. Name your script. In this example, the new script is called “Outline”.
3. Enter the following code:

```C#
using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class Outline : CustomPass
{
    public LayerMask    outlineLayer = 0;
    [ColorUsage(false, true)]
    public Color        outlineColor = Color.black;
    public float        threshold = 1;

    // To make sure the shader ends up in the build, we keep a reference to it
    [SerializeField, HideInInspector]
    Shader                  outlineShader;

    Material                fullscreenOutline;
    RTHandle                outlineBuffer;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        outlineShader = Shader.Find("Hidden/Outline");
        fullscreenOutline = CoreUtils.CreateEngineMaterial(outlineShader);

        // Define the outline buffer
        outlineBuffer = RTHandles.Alloc(
            Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.B10G11R11_UFloatPack32,
// We don't need alpha for this effect
            useDynamicScale: true, name: "Outline Buffer"
        );
    }

    protected override void Execute(CustomPassContext ctx)
    {
        // Render meshes we want to apply the outline effect to in the outline buffer
        CoreUtils.SetRenderTarget(ctx.cmd, outlineBuffer, ClearFlag.Color);
        CustomPassUtils.DrawRenderers(ctx, outlineLayer);

        // Set up outline effect properties
        ctx.propertyBlock.SetColor("_OutlineColor", outlineColor);
        ctx.propertyBlock.SetTexture("_OutlineBuffer", outlineBuffer);
        ctx.propertyBlock.SetFloat("_Threshold", threshold);

        // Render the outline buffer fullscreen
        CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ClearFlag.None);
        CoreUtils.DrawFullScreen(ctx.cmd, fullscreenOutline, ctx.propertyBlock, shaderPassId: 0);
    }

    protected override void Cleanup()
    {
        CoreUtils.Destroy(fullscreenOutline);
        outlineBuffer.Release();
    }
}
```

<a name="Creating-Cusom-Pass-Shader"></a>

### Scripting a Custom Pass shader

To create a new shader:

1. Create a new Unity shader using **Assets> Create> Shader > HDRP Custom FullScreen Pass**
2. Name the new shader source file “Outline”
3. Enter the following code:

```C#
Shader "Hidden/Outline"
{
    HLSLINCLUDE

    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone vulkan metal switch

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

    TEXTURE2D_X(_OutlineBuffer);
    float4 _OutlineColor;
    float _Threshold;

    #define v2 1.41421
    #define c45 0.707107
    #define c225 0.9238795
    #define s225 0.3826834

    #define MAXSAMPLES 8
    // Neighbour pixel positions
    static float2 samplingPositions[MAXSAMPLES] =
    {
        float2( 1,  1),
        float2( 0,  1),
        float2(-1,  1),
        float2(-1,  0),
        float2(-1, -1),
        float2( 0, -1),
        float2( 1, -1),
        float2( 1, 0),
    };

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float4 color = float4(0.0, 0.0, 0.0, 0.0);
        float luminanceThreshold = max(0.000001, _Threshold * 0.01);

        // Load the camera color buffer at the mip 0 if we're not at the before rendering injection point
        if (_CustomPassInjectionPoint != CUSTOMPASSINJECTIONPOINT_BEFORE_RENDERING)
            color = float4(CustomPassSampleCameraColor(posInput.positionNDC.xy, 0), 1);

        // When sampling RTHandle texture, always use _RTHandleScale.xy to scale your UVs first.
        float2 uv = posInput.positionNDC.xy * _RTHandleScale.xy;
        float4 outline = SAMPLE_TEXTURE2D_X_LOD(_OutlineBuffer, s_linear_clamp_sampler, uv, 0);
        outline.a = 0;

      // If this sample is below the threshold
        if (Luminance(outline.rgb) < luminanceThreshold)
        {
            // Search neighbors
            for (int i = 0; i < MAXSAMPLES; i++)
            {
                float2 uvN = uv + _ScreenSize.zw * _RTHandleScale.xy * samplingPositions[i];
                float4 neighbour = SAMPLE_TEXTURE2D_X_LOD(_OutlineBuffer, s_linear_clamp_sampler, uvN, 0);

                if (Luminance(neighbour) > luminanceThreshold)
                {
                    outline.rgb = _OutlineColor.rgb;
                    outline.a = 1;
                    break;
                }
            }
        }

        return outline;
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}
```

### Using a C# Custom Pass Shader effect

To enable a full-screen effect that you have created in a shader, assign it to the **FullScreen Material** property of a [**FullScreeenCustomPass**](Custom-Pass-Creating.md#Full-Screen-Custom-Pass) component.

To enable a Draw renderers Custom Pass that you have created in a shader, assign it to the Material property of a [**DrawRenderersCustomPass**](Custom-Pass-Creating.md#Draw-Renderers-Custom-Pass) component.

You can also make your Custom Pass effect visible automatically in script. To do this, assign a Material to a shader within a Custom Pass script. The example script provided in [Creating a Custom Pass script](#Creating-Cusom-Pass-script) does this in the following lines:

Reference the shader in a serialized field:

```c#
// To make sure the shader ends up in the build, we keep a reference to it
​    [SerializeField, HideInInspector]
​    Shader                  outlineShader;
```

Reference the shader when you create a material:

```c#
fullscreenOutline = CoreUtils.CreateEngineMaterial(outlineShader);
```


## Controlling a Custom Pass Volume component using code

You can use [GetComponent](https://docs.unity3d.com/2019.3/Documentation/ScriptReference/GameObject.GetComponent.html) to retrieve the `CustomPassVolume` in a script and access most of the properties available in the UI (for example,`isGlobal`, `fadeRadius` and `injectionPoint`).

You can also dynamically change the list of Custom Passes that Unity executes. To do this, modify the `customPasses` list.

The following example copies the current camera color buffer to a render texture asset:

```C#
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
// Custom pass to copy the current camera color buffer to a render texture asset
public class CopyPass : CustomPass
{
    public RenderTexture colorBuffer;
    protected override void Execute(CustomPassContext ctx)
    {
        if (colorBuffer != null)
        {
            var scale = RTHandles.rtHandleProperties.rtHandleScale;
            ctx.cmd.Blit(ctx.cameraColorBuffer, colorBuffer, new Vector2(scale.x, scale.y), Vector2.zero, 0, 0);
            // Notify Unity that the color buffer content changed.
            colorBuffer.IncrementUpdateCount();
        }
    }
}
public class ExtractColorBuffer : MonoBehaviour
{
    public RenderTexture            colorBuffer;
    public CustomPassInjectionPoint injectionPoint;
    CustomPassVolume    volume;
    CopyPass            copyPass;
    void Start()
    {
        volume = gameObject.AddComponent<CustomPassVolume>();
        // Make the volume invisible in the inspector
        volume.hideFlags = HideFlags.HideInInspector | HideFlags.DontSave;
        // Add the copy pass to the hidden custom pass volume
        copyPass = volume.AddPassOfType(typeof(CopyPass)) as CopyPass;
    }
    void Update()
    {
        // Sync properties in case they change in the editor
        copyPass.colorBuffer = colorBuffer;
        volume.injectionPoint = injectionPoint;
    }
}
```

### Creating a custom editor for a C# custom pass

To write a custom editor you can use a similar pattern to the [CustomPropertyDrawer](https://docs.unity3d.com/ScriptReference/CustomPropertyDrawer.html) MonoBehaviour Editor, but with different attributes.

The following script creates a [custom editor](https://docs.unity3d.com/Manual/editor-CustomEditors.html) that you can use to customize the properties of a Custom Pass in the Inspector window:

```C#
public class OutlineDrawer : CustomPassDrawer
{
   // This property field allow you to control which common UI property to show.
   // For the outline we only need the name and target color buffer.
   protected override PassUIFlag commonPassUIFlags => PassUIFlag.TargetColorBuffer | PassUIFlag.Name;
   SerializedProperty outlineLayer, outlineColor, threshold;
   static float lineAndSpaceHeight = EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;
   protected override void Initialize(SerializedProperty customPass)
   {
       // Initialize the local SerializedProperty you will use in your pass.
       outlineLayer = customPass.FindPropertyRelative(nameof(Outline.outlineLayer));
       outlineColor = customPass.FindPropertyRelative(nameof(Outline.outlineColor));
       threshold = customPass.FindPropertyRelative(nameof(Outline.threshold));
   }
   protected override void DoPassGUI(SerializedProperty customPass, Rect rect)
   {
       // Draw your custom GUI using `EditorGUI` calls. Note that the Layout methods don't work here
       Rect propertyRect = rect;
       propertyRect.height = EditorGUIUtility.singleLineHeight;
       EditorGUI.PropertyField(propertyRect, outlineLayer);
       propertyRect.y += lineAndSpaceHeight;
       EditorGUI.PropertyField(propertyRect, outlineColor);
       propertyRect.y += lineAndSpaceHeight;
       EditorGUI.PropertyField(propertyRect, threshold);
   }
   protected override float GetPassHeight(SerializedProperty customPass)
   {
       // Return the vertical height in pixels that you used in the DoPassGUI method above.
       // Can be dynamic.
       return (lineAndSpaceHeight) * 3;
   }
}

{
   // This property field allow you to control which common UI property to show.
   // For the outline we only need the name and target color buffer.
   protected override PassUIFlag commonPassUIFlags => PassUIFlag.TargetColorBuffer | PassUIFlag.Name;
   SerializedProperty outlineLayer, outlineColor, threshold;
   static float lineAndSpaceHeight = EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;
   protected override void Initialize(SerializedProperty customPass)
   {
       // Initialize the local SerializedProperty you will use in your pass.
       outlineLayer = customPass.FindPropertyRelative(nameof(Outline.outlineLayer));
       outlineColor = customPass.FindPropertyRelative(nameof(Outline.outlineColor));
       threshold = customPass.FindPropertyRelative(nameof(Outline.threshold));
   }
   protected override void DoPassGUI(SerializedProperty customPass, Rect rect)
   {
       // Draw your custom GUI using `EditorGUI` calls. Note that the Layout methods don't work here
       Rect propertyRect = rect;
       propertyRect.height = EditorGUIUtility.singleLineHeight;
       EditorGUI.PropertyField(propertyRect, outlineLayer);
       propertyRect.y += lineAndSpaceHeight;
       EditorGUI.PropertyField(propertyRect, outlineColor);
       propertyRect.y += lineAndSpaceHeight;
       EditorGUI.PropertyField(propertyRect, threshold);
   }
   protected override float GetPassHeight(SerializedProperty customPass)
   {
       // Return the vertical height in pixels that you used in the DoPassGUI method above.
       // Can be dynamic.
       return (lineAndSpaceHeight) * 3;
   }
}
```

When you create a Custom Pass drawer, Unity provides a default list of Custom Pass properties. Unity still does this when `DoPassGUI` is empty. These properties are the same properties that Unity provides in the [draw renderers CustomPass Volume](Custom-Pass-Creating.md#Draw-Renderers-Custom-Pass) component by default.

If you don't need all of these settings, you can override the `commonPassUIFlags` property to remove some of them. The following example only keeps the name and the target buffer enum:

```c#
protected override PassUIFlag commonPassUIFlags => PassUIFlag.Name | PassUIFlag.TargetColorBuffer;
```
