import { NextResponse } from 'next/server';

export function GET() {
  return unavailableApiResponse();
}

export function POST() {
  return unavailableApiResponse();
}

export function PUT() {
  return unavailableApiResponse();
}

export function PATCH() {
  return unavailableApiResponse();
}

export function DELETE() {
  return unavailableApiResponse();
}

function unavailableApiResponse() {
  return NextResponse.json(
    {
      message: 'La API no esta conectada. Configura NEXT_PUBLIC_API_URL con la URL publica del backend.'
    },
    { status: 503 }
  );
}
