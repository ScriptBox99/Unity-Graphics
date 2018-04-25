using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;
using UnityEngine.Experimental.VFX;

namespace UnityEditor.VFX
{
    class VFXConeGizmo : VFXSpaceableGizmo<Cone>
    {
        IProperty<Vector3> m_CenterProperty;
        IProperty<float> m_Radius0Property;
        IProperty<float> m_Radius1Property;
        IProperty<float> m_HeightProperty;

        public override void RegisterEditableMembers(IContext context)
        {
            m_CenterProperty = context.RegisterProperty<Vector3>("center");
            m_Radius0Property = context.RegisterProperty<float>("radius0");
            m_Radius1Property = context.RegisterProperty<float>("radius1");
            m_HeightProperty = context.RegisterProperty<float>("height");
        }

        public static readonly Vector3[] radiusDirections = new Vector3[] { Vector3.left, Vector3.up, Vector3.right, Vector3.down };


        public struct Extremities
        {
            public Extremities(Cone cone)
            {
                topCap = cone.height * Vector3.up;
                bottomCap = Vector3.zero;

                extremities = new Vector3[8];

                extremities[0] = topCap + Vector3.forward * cone.radius1;
                extremities[1] = topCap - Vector3.forward * cone.radius1;

                extremities[2] = topCap + Vector3.left * cone.radius1;
                extremities[3] = topCap - Vector3.left * cone.radius1;

                extremities[4] = bottomCap + Vector3.forward * cone.radius0;
                extremities[5] = bottomCap - Vector3.forward * cone.radius0;

                extremities[6] = bottomCap + Vector3.left * cone.radius0;
                extremities[7] = bottomCap - Vector3.left * cone.radius0;
            }

            public Extremities(Cone cone, float degArc)
            {
                topCap = cone.height * Vector3.up;
                bottomCap = Vector3.zero;

                int count = Mathf.CeilToInt(degArc / 90);

                extremities = new Vector3[count * 2];

                int cpt = 0;
                extremities[cpt++] = topCap + Vector3.forward * cone.radius1;
                if (count > 1)
                {
                    extremities[cpt++] = topCap - Vector3.left * cone.radius1;
                    if (count > 2)
                    {
                        extremities[cpt++] = topCap - Vector3.forward * cone.radius1;
                        if (count > 3)
                        {
                            extremities[cpt++] = topCap + Vector3.left * cone.radius1;
                        }
                    }
                }
                extremities[cpt++] = bottomCap + Vector3.forward * cone.radius0;
                if (count > 1)
                {
                    extremities[cpt++] = bottomCap - Vector3.left * cone.radius0;
                    if (count > 2)
                    {
                        extremities[cpt++] = bottomCap - Vector3.forward * cone.radius0;
                        if (count > 3)
                        {
                            extremities[cpt++] = bottomCap + Vector3.left * cone.radius0;
                        }
                    }
                }
            }

            public Vector3 topCap;
            public Vector3 bottomCap;
            public Vector3[] extremities;
        }


        public static void DrawCone(Cone cone, VFXGizmo gizmo, ref Extremities extremities, IProperty<Vector3> centerProperty, IProperty<float> radius0Property, IProperty<float> radius1Property, IProperty<float> heightProperty)
        {
            gizmo.PositionGizmo(cone.center, centerProperty, true);

            using (new Handles.DrawingScope(Handles.matrix * Matrix4x4.Translate(cone.center)))
            {
                if (radius0Property.isEditable)
                {
                    for (int i = extremities.extremities.Length / 2; i < extremities.extremities.Length; ++i)
                    {
                        EditorGUI.BeginChangeCheck();

                        Vector3 pos = extremities.extremities[i];
                        Vector3 result = Handles.Slider(pos, pos - extremities.bottomCap, handleSize * HandleUtility.GetHandleSize(pos), Handles.CubeHandleCap, 0);

                        if (EditorGUI.EndChangeCheck())
                        {
                            radius0Property.SetValue(result.magnitude);
                        }
                    }
                }

                if (radius1Property.isEditable)
                {
                    for (int i = 0; i < extremities.extremities.Length / 2; ++i)
                    {
                        EditorGUI.BeginChangeCheck();

                        Vector3 pos = extremities.extremities[i];
                        Vector3 dir = pos - extremities.topCap;
                        Vector3 result = Handles.Slider(pos, dir, handleSize * HandleUtility.GetHandleSize(pos), Handles.CubeHandleCap, 0);

                        if (EditorGUI.EndChangeCheck())
                        {
                            radius1Property.SetValue((result - extremities.topCap).magnitude);
                        }
                    }
                }

                if (heightProperty.isEditable)
                {
                    EditorGUI.BeginChangeCheck();
                    Vector3 result = Handles.Slider(extremities.topCap, Vector3.up, handleSize * HandleUtility.GetHandleSize(extremities.topCap), Handles.CubeHandleCap, 0);

                    if (EditorGUI.EndChangeCheck())
                    {
                        heightProperty.SetValue(result.magnitude);
                    }
                }
            }
        }

        public override void OnDrawSpacedGizmo(Cone cone)
        {
            Extremities extremities = new Extremities(cone);
            using (new Handles.DrawingScope(Handles.matrix * Matrix4x4.Translate(cone.center)))
            {
                Handles.DrawWireDisc(extremities.topCap, Vector3.up, cone.radius1);
                Handles.DrawWireDisc(extremities.bottomCap, Vector3.up, cone.radius0);

                for (int i = 0; i < extremities.extremities.Length / 2; ++i)
                {
                    Handles.DrawLine(extremities.extremities[i], extremities.extremities[i + extremities.extremities.Length / 2]);
                }
            }

            DrawCone(cone, this, ref extremities, m_CenterProperty, m_Radius0Property, m_Radius1Property, m_HeightProperty);
        }
    }
    class VFXArcConeGizmo : VFXSpaceableGizmo<ArcCone>
    {
        IProperty<Vector3> m_CenterProperty;
        IProperty<float> m_Radius0Property;
        IProperty<float> m_Radius1Property;
        IProperty<float> m_HeightProperty;
        IProperty<float> m_ArcProperty;

        public override void RegisterEditableMembers(IContext context)
        {
            m_CenterProperty = context.RegisterProperty<Vector3>("center");
            m_Radius0Property = context.RegisterProperty<float>("radius0");
            m_Radius1Property = context.RegisterProperty<float>("radius1");
            m_HeightProperty = context.RegisterProperty<float>("height");
            m_ArcProperty = context.RegisterProperty<float>("arc");
        }

        public static readonly Vector3[] radiusDirections = new Vector3[] { Vector3.left, Vector3.up, Vector3.right, Vector3.down };
        public override void OnDrawSpacedGizmo(ArcCone arcCone)
        {
            float arc = arcCone.arc * Mathf.Rad2Deg;
            Cone cone = new Cone { center = arcCone.center, radius0 = arcCone.radius0, radius1 = arcCone.radius1, height = arcCone.height };
            var extremities = new VFXConeGizmo.Extremities(cone, arc);
            Vector3 arcDirection = Quaternion.AngleAxis(arc, Vector3.up) * Vector3.forward;

            using (new Handles.DrawingScope(Handles.matrix * Matrix4x4.Translate(arcCone.center)))
            {
                Handles.DrawWireArc(extremities.topCap, Vector3.up, Vector3.forward, arc, arcCone.radius1);
                Handles.DrawWireArc(extremities.bottomCap, Vector3.up, Vector3.forward, arc, arcCone.radius0);

                for (int i = 0; i < extremities.extremities.Length / 2; ++i)
                {
                    Handles.DrawLine(extremities.extremities[i], extremities.extremities[i + extremities.extremities.Length / 2]);
                }

                Handles.DrawLine(extremities.topCap, extremities.extremities[0]);
                Handles.DrawLine(extremities.bottomCap, extremities.extremities[extremities.extremities.Length / 2]);


                Handles.DrawLine(extremities.topCap, extremities.topCap + arcDirection * arcCone.radius1);
                Handles.DrawLine(extremities.bottomCap, arcDirection * arcCone.radius0);

                Handles.DrawLine(arcDirection * arcCone.radius0, extremities.topCap + arcDirection * arcCone.radius1);
            }

            VFXConeGizmo.DrawCone(cone, this, ref extremities, m_CenterProperty, m_Radius0Property, m_Radius1Property, m_HeightProperty);

            float radius = arcCone.radius0 > arcCone.radius1 ? arcCone.radius0 : arcCone.radius1;
            Vector3 center = arcCone.radius0 > arcCone.radius1 ? Vector3.zero : extremities.topCap;
            Vector3 arcHandlePosition = arcDirection * radius;

            ArcGizmo(center, radius, arc, m_ArcProperty, Quaternion.identity, true);
        }
    }
}
